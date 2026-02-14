FROM temporalio/auto-setup:1.28.1

COPY development-sql.yaml /etc/temporal/config/dynamicconfig/development-sql.yaml

ENV DB=postgres12
ENV DYNAMIC_CONFIG_FILE_PATH=config/dynamicconfig/development-sql.yaml
ENV ENABLE_ES=true
ENV ES_VERSION=v7
ENV TEMPORAL_NAMESPACE=default

EXPOSE 7233
