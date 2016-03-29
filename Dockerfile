FROM debian:jessie

RUN apt-get update && \
    apt-get install -y ansible ssh && \
    rm -rf /var/lib/apt/lists/*

ADD ./playbooks /playbooks
ADD ./conf/ansible.cfg /etc/ansible/ansible.cfg
ADD ./entrypoint.sh /entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
