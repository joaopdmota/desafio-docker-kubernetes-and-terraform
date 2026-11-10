# Prova de autoscaling da API

Data da execução: 10 de novembro de 2026.

## Comando

```bash
make docker-load
```

## Resultado observado

```text
deployment.apps/mural-mural-api condition met
Waiting for Metrics Server to publish API metrics...
Starting concurrent load against the internal API Service...
Waiting for the HPA to request more than one replica...
desired replicas=5, average CPU=167%

NAME              REFERENCE                    TARGETS         MINPODS   MAXPODS   REPLICAS
mural-mural-api   Deployment/mural-mural-api   cpu: 167%/30%   1         5         4

NAME                               READY   STATUS
mural-mural-api-7859b5945d-2r5vc   1/1     Running
mural-mural-api-7859b5945d-8bnb7   1/1     Running
mural-mural-api-7859b5945d-c6dhk   1/1     Running
mural-mural-api-7859b5945d-fm9c9   1/1     Running
mural-mural-api-7859b5945d-nlgd2   1/1     Running

HPA scale-out proven. It will return toward minReplicas after the stabilization window.
```

## Interpretação

- Meta configurada: 30% da CPU request por pod.
- Utilização média observada: 167%.
- Réplicas mínimas: 1.
- Réplicas desejadas pelo HPA durante a carga: 5.
- Réplicas máximas: 5.
- Cinco pods da API chegaram ao estado `Running`.

O campo `REPLICAS` da tabela do HPA ainda mostrava 4 enquanto a listagem já
mostrava 5 pods. Essa diferença momentânea é esperada porque os controladores e
os campos de status do Kubernetes são atualizados de maneira assíncrona. O
estado convergiu para as cinco réplicas solicitadas.

O pod gerador de carga foi removido pelo script após a comprovação. Sem carga, o
HPA respeita a janela de estabilização de 60 segundos e reduz gradualmente até
`minReplicas: 1`.
