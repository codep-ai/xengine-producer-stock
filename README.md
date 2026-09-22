# xengine-producer-stock

Producing team's dbt project. Athena builds the common stock tables as Apache Iceberg (merge models) into Glue database
`stock_common_mesh`. Any engine may consume them; consumers are separate repos (`xengine-consumer-analytics`, `xengine-consumer-ml`).
The contract with consumers is the table's physical identity `glue:stock_common_mesh.<table>` and its declared columns.

    ./xdbt.sh build
    ./xdbt.sh docs generate

Estate-level lineage across the repos: `xengine-estate-stock/estate.yml` + `datapai-platform-be/scripts/xengine.py lineage --estate`.
Models are copies of `dbt-demo/xengine_stock/models/producer_athena` (single-project shape kept for comparison).
