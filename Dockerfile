# Lightweight nginx image serving a static page
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
