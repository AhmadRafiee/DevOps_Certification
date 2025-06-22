# How To Deploy Grafana Loki and Save Data to MinIO
![grafanaloki-minio](../../images/grafanaloki-minio.jpg)

Grafana Loki is a log aggregation system that stores and queries logs from applications and infrastructure. Although commonplace, logs hold critical information about system operations and are a valuable source of debugging and troubleshooting information. Logs are frequently used to identify and track malicious activity, or simply to track user activity to provide business intelligence.

In an earlier blog post, Logging with Grafana Loki and MinIO, we provided an overview of Loki’s components and their overall architecture. Think of Loki for logs as analogous to Prometheus for metrics. Loki is lightweight and cost-effective because it only indexes and queries metadata. Promtail agents collect, label and transform logs before sending them to Loki. Then Loki indexes metadata and groups entries into streams that are indexed with labels. Grafana is then used to visualize and query log information from Loki. As of version 2.0, Loki stores data in a single object storage backend, such as MinIO. Whereas the previous blog post explained the advantages of saving Loki data to MinIO, this blog post is a tutorial that teaches you how.

First, we’ll teach you how to deploy Loki and MinIO using Docker containers, followed by instructions on how to install from source.

### Learn Loki and Master MinIO Using Docker Containers

We built a demo using Docker containers, some scripting and a Git repository. We started with the Grafana Loki repository, and added configuration yaml and containers for MinIO and a script to create and expose a MinIO bucket for Loki data. The following steps will result in these five images running locally in Docker containers:

  - Loki
  - Promtail
  - Grafana
  - MinIO
  - Create buckets

The first three are obviously needed for Loki, Promtail and Grafana. They were already available from Grafana under the Loki repository (there is a short video explainer). MinIO is object storage for Loki, and the final container will run a script that creates buckets as Loki targets.

Loki has been configured to save log data to MinIO using `loki.yaml`. Of particular importance is the section:
```yaml
storage_config:
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/index_cache
    resync_interval: 5s
    shared_store: s3
  aws:
    s3: http://miniouser:miniopass@minio.:9000/loki
    s3forcepathstyle: true
```
  - **miniouser:** minio accesskey
  - **miniopass:** minio secret key
  - **minio.:9000:** minio api endpoint
  - **loki:** minio bucket


[Reference](https://blog.min.io/how-to-grafana-loki-minio/)