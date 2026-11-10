FROM nginx:1.27-alpine
COPY app/web/ /usr/share/nginx/html/
RUN rm /usr/share/nginx/html/nginx.conf.template
COPY app/web/nginx.conf.template /etc/nginx/templates/default.conf.template
ENV API_UPSTREAM=api:8080
EXPOSE 8080

