FROM nginx:1.27-alpine

# Remove default content and copy our static site
RUN rm -rf /usr/share/nginx/html/*
COPY index.html /usr/share/nginx/html/index.html

HEALTHCHECK --interval=15s --timeout=5s --retries=3 \
  CMD wget -q --spider http://localhost/ || exit 1

EXPOSE 80
