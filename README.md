# Mural de Recados — Docker, Kubernetes e Terraform

Esta entrega leva o Mural de um Compose de desenvolvimento a um cluster kind gerenciado integralmente por Terraform. O fluxo cria o cluster, constrói e carrega as imagens locais, instala o Traefik e instala o chart Helm. A senha do PostgreSQL é gerada pelo provider `random`, marcada como sensível pelo Terraform e materializada somente em um `Secret`.

## Pré-requisitos

- Docker com o daemon em execução
- Terraform >= 1.6
- kind >= 0.20
- portas locais 80 e 443 livres
- acesso à internet no primeiro `terraform init/apply` (providers, chart Traefik e imagens-base)

Helm e kubectl são úteis para diagnóstico, mas o `apply` não depende dos CLIs deles. `mural.localtest.me` resolve publicamente para `127.0.0.1`, portanto não é necessário editar `/etc/hosts`.

## Executar

```bash
make up
open http://mural.localtest.me       # macOS
# ou: xdg-open http://mural.localtest.me
```

O comando equivalente, sem Make:

```bash
terraform -chdir=infra/terraform init
terraform -chdir=infra/terraform apply
```

### Executar sem instalar Terraform

Se a máquina tiver apenas Docker com Compose, use o toolbox Docker-in-Docker incluído no projeto. Terraform, kind e kubectl rodam dentro dele:

```bash
make docker-up
open http://mural.localtest.me
```

Valide a idempotência e consulte o cluster:

```bash
make docker-plan       # esperado: No changes
make docker-status
```

Destrua primeiro os recursos e depois desligue o toolbox:

```bash
make docker-down
make tools-down
```

O serviço `infra` é privilegiado porque executa um daemon Docker isolado dentro do container. O volume `mural-docker-data` mantém o daemon e o cluster entre os comandos. Para também apagar esse cache depois do `destroy`, execute `docker compose -f docker-compose.tools.yml down -v`.

Validação:

```bash
curl --fail http://mural.localtest.me/api/messages
kubectl --kubeconfig infra/terraform/.kubeconfig -n mural get pods,pvc,ingress
terraform -chdir=infra/terraform plan # esperado: No changes
```

## Bônus: autoscaling da API

O chart inclui um HPA `autoscaling/v2` que mantém de 1 a 5 réplicas da API e
busca aproximadamente 30% de utilização média de CPU. O Terraform instala o
Metrics Server oficial com a opção de TLS necessária ao kubelet do kind.

Depois do `make docker-up`, execute a prova automatizada:

```bash
make docker-load
```

O teste espera as métricas, cria 50 workers HTTP dentro do cluster e acompanha
o HPA. Ele só termina com sucesso depois que `desiredReplicas` for maior que 1.
Ao encerrar a carga, o HPA volta gradualmente para `minReplicas: 1`.

Uma execução comprovada está registrada em [docs/prova-hpa.md](docs/prova-hpa.md).

Remoção completa:

```bash
make down
```

O cluster kind contém o PVC, releases e namespaces; ao destruir o cluster, todos são removidos. O arquivo `.kubeconfig` é gerenciado pelo resource do kind.

## Compose de desenvolvimento

O Compose usa deliberadamente imagens oficiais e executa `db → migrate → api → web`, como pedido no desafio:

```bash
docker compose up
# http://localhost:8080
```

## Decisões

- A API usa build multi-stage, `CGO_ENABLED=0`, símbolos removidos e runtime `scratch` com usuário não-root. O estágio final contém somente CA certificates e o binário.
- O nginx usa o mecanismo nativo `/etc/nginx/templates` da imagem oficial para substituir `API_UPSTREAM` na inicialização; a imagem não precisa ser recompilada por ambiente.
- `/healthz` é liveness da API; `/readyz` é readiness e só passa após banco e tabela responderem.
- A migração é um hook Helm `post-install,post-upgrade`. O release usa `wait=false` para que o Helm não espere a readiness da API antes de executar o Job. O hook, por sua vez, é aguardado pelo Helm e roda uma vez a cada revisão.
- O Postgres é StatefulSet com `volumeClaimTemplates`, Service headless e PVC `standard` do kind.
- O Terraform usa hashes do conteúdo de `app/` como gatilho: imagens só são reconstruídas/carregadas quando fonte, Dockerfile, tag ou cluster muda. Isso preserva o segundo apply sem alterações.
- O Traefik roda como DaemonSet somente no nó rotulado `ingress-ready=true`, com `hostPort` 80/443 alinhado aos port mappings do kind.

## Tamanho da imagem da API

Resultado de referência em `linux/amd64` (o valor exato varia com versão/plataforma):

| Imagem | Tamanho local |
|---|---:|
| `golang:1.23-alpine` (baseline com toolchain) | ~250 MB |
| `mural-api:local` (`scratch`) | ~6 MB |

Para registrar os números exatos da máquina avaliadora:

```bash
docker pull golang:1.23-alpine
docker build -f app/docker/api.Dockerfile -t mural-api:local .
docker image inspect golang:1.23-alpine mural-api:local --format '{{.RepoTags}} {{.Size}} bytes'
```

O binário estático desta entrega foi validado com 5,9 MiB em `linux/arm64`; o tamanho da imagem `scratch` fica praticamente igual. Em relação ao baseline de ~250 MB, isso representa aproximadamente 97% de redução, além de retirar shell, package manager, toolchain e código-fonte do runtime.

## Segredos

Nenhuma credencial Kubernetes está versionada. A senha aleatória fica no Secret do cluster e, como em qualquer uso de valores secretos pelo Terraform, também no state local. Em ambiente compartilhado, o backend do state deve ter criptografia e controle de acesso. A senha `mural-local` do Compose é exclusivamente uma credencial descartável do ambiente de desenvolvimento.

