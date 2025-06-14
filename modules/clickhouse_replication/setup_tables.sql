-- Create a database on the cluster
CREATE DATABASE IF NOT EXISTS db1 ON CLUSTER cluster_2S_1R;

-- Create a table with MergeTree table engine on the cluster
CREATE TABLE IF NOT EXISTS db1.table1 ON CLUSTER cluster_2S_1R
(
    `id` UInt64,
    `column1` String
)
ENGINE = MergeTree
ORDER BY id;

-- Create a distributed table to query both shards on both nodes
CREATE TABLE IF NOT EXISTS db1.table1_dist ON CLUSTER cluster_2S_1R
(
    `id` UInt64,
    `column1` String
)
ENGINE = Distributed('cluster_2S_1R', 'db1', 'table1', rand());

-- Insert some test data
INSERT INTO db1.table1 VALUES (1, 'test data from node 1');