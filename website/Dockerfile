FROM nginx:alpine

# Static site
COPY site/ /usr/share/nginx/html/

# Optional: basic security headers
COPY nginx.conf /etc/nginx/conf.d/default.conf
