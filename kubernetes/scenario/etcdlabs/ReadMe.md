# etcdlabs

**etcdlabs** is an open-source, interactive learning platform designed to help users explore and understand the inner workings of the **etcd distributed key-value store**. It provides hands-on simulations and visualizations to make distributed systems concepts easier to grasp.

## Features

- **Interactive Simulations**: Experiment with etcd features like key-value storage, leader elections, and fault tolerance.
- **Raft Consensus Algorithm**: Visualize how Raft ensures data consistency and manages cluster states.
- **Cluster Management**: Add, remove, or recover nodes to see how etcd handles membership changes.
- **Failure Handling**: Simulate node failures, network partitions, and leader recovery scenarios.
- **Educational Focus**: Perfect for developers, operators, and students learning distributed systems.

## Why Use etcdlabs?

1. **Learn Distributed Systems**: Understand concepts like consensus, replication, and fault tolerance.
2. **Hands-On Experience**: Practice using etcd in a safe, simulated environment.
3. **Debugging & Troubleshooting**: Explore how etcd handles real-world issues like node failures and network splits.
4. **Teaching Tool**: Ideal for educators and trainers explaining etcd and distributed systems.

## Who Should Use etcdlabs?

- **Developers**: Gain a deeper understanding of etcd before integrating it into your application.
- **Operators**: Learn best practices for managing etcd clusters in production.
- **Students**: Get hands-on experience with distributed systems in a visual, interactive way.
- **Educators**: Use etcdlabs to teach complex concepts with ease.

## Getting Started

### Prerequisites
- A modern web browser (for interactive simulations).
- Basic knowledge of distributed systems is helpful but not required.

### Installation
Copy compose file and run it:
```bash
docker network create web_net
docker compose up -d
docker logs -f etcdlabs
```
