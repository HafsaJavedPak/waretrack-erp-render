# Same image you run locally (frappe_docker/pwd.yml), plus Redis so the whole
# app tier runs in ONE Render service with ONE persistent disk.
FROM frappe/erpnext:v16.53.0

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends redis-server \
 && rm -rf /var/lib/apt/lists/*

# Render SSH needs ~/.ssh (0700) for the running user, and a home dir that is
# not group/world-writable. https://render.com/docs/ssh#docker-specific-configuration
RUN mkdir -p /home/frappe/.ssh \
 && chown frappe:root /home/frappe/.ssh \
 && chmod 0700 /home/frappe/.ssh \
 && chmod 0755 /home/frappe \
 && usermod -s /bin/bash frappe

COPY --chown=frappe:root render/ /home/frappe/render/
RUN chmod +x /home/frappe/render/*.sh

USER frappe
# The image's ENTRYPOINT (assets symlink) is kept; we only replace CMD.
CMD ["/home/frappe/render/start.sh"]
