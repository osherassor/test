FROM gitlab/gitlab-ce:17.6.1-ce.0

ENV GITLAB_OMNIBUS_CONFIG="\
  external_url 'http://localhost:3000'; \
  gitlab_rails['initial_root_password'] = 'Ph0b0s!Relay#xZ9qW2'; \
  nginx['listen_port'] = 3000; \
  letsencrypt['enable'] = false; \
  gitlab_rails['gitlab_signup_enabled'] = false; \
  gitlab_rails['usage_ping_enabled'] = false; \
  prometheus_monitoring['enable'] = false; \
  gitlab_rails['gitlab_shell_ssh_port'] = 2222; \
"

COPY seed_repo.sh /assets/seed_repo.sh
COPY entrypoint.sh /assets/entrypoint.sh
RUN chmod +x /assets/seed_repo.sh /assets/entrypoint.sh

EXPOSE 3000 22

CMD ["/assets/entrypoint.sh"]
