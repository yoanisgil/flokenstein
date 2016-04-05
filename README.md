# Flokenstein

Provision a Flocker cluster running on top of Docker Swarm using Docker Machine/Docker Compose and Ansible

# Setup

- Configure environment variables for creating a Swarm Cluster on top of AWS

```
export AWS_ACCESS_KEY_ID=*YOUR_AWS_ACCESS_KEY_ID*
export AWS_SECRET_ACCESS_KEY=*YOUR_AWS_SECRET_ACCESS_KEY*
```

- Create an instance where the Key/Value store will be running:
    
```
docker-machine create --driver amazonec2 kvstore
```

- Run a Consul container on the just created *kvstore* EC2 instance:

```
eval $(docker-machine env kvstore)
export KV_IP=$(docker-machine ip kvstore)
docker run -d -p 8500:8500 -h consul --restart=always progrium/consul -server -bootstrap
```

- Create an instance for running the Swarm master:

```
docker-machine create -d amazonec2 --swarm  --swarm-master --swarm-discovery="consul://${KV_IP}:8500" --engine-opt="cluster-store=consul://${KV_IP}:8500"  --engine-opt="cluster-advertise=eth0:2376"  swarm-master
```


- Create another instance for running a Swarm Node:

```
docker-machine create -d amazonec2 --swarm --swarm-discovery="consul://${KV_IP}:8500" --engine-opt="cluster-store=consul://${KV_IP}:8500" --engine-opt="cluster-advertise=eth0:2376" swarm-node-01
```

- Activate Swarm:

```
eval $(docker-machine env --swarm swarm-master)
```

# Node provisioning

With the Swarm cluster in place we can now start provisiong nodes. First intsall some handy packages (htop, jq, etc):

```
docker-compose run -e constraint:node==swarm-master --rm provision playbooks/bootstrap.yml
docker-compose run -e constraint:node==swarm-node-01 --rm provision playbooks/bootstrap.yml
```

- Install Flocker software:


```
docker-compose run -e constraint:node==swarm-master --rm provision playbooks/flocker-common.yml
docker-compose run -e constraint:node==swarm-node-01 --rm provision playbooks/flocker-common.yml
```

- Get the internal IP of the control node:

```
docker-machine ssh swarm-master ifconfig eth0

eth0      Link encap:Ethernet  HWaddr 12:26:ba:ed:52:c3
          inet addr:*******172.31.51.42*******  Bcast:172.31.63.255  Mask:255.255.240.0
          inet6 addr: fe80::1026:baff:feed:52c3/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:9001  Metric:1
          RX packets:260750 errors:0 dropped:0 overruns:0 frame:0
          TX packets:19940 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:375002678 (375.0 MB)  TX bytes:3459878 (3.4 MB)

```

- Make sure ports ```4523``` and ```4524``` are accesible for machines inside the Swarm cluster. The final configuration should look like:

![Inbound ports config for the docker-machine security group](https://raw.githubusercontent.com/yoanisgil/flokenstein/master/aws-security-group-config.png)


- Export the IP address from the step above as an environment variable:

```
export FLOCKER_CONTROL_IP=172.31.51.42
```


- Configure a Flocker Control Service:

```
docker-compose run -e constraint:node==swarm-master --rm provision playbooks/flocker-configure-control-node.yml
```


- Configure a Flocker node on the Swarm master:

```
./copy-node-certifica.sh swarm-master swarm-master
```

- Configure the flocker agent:

```
export AWS_REGION=us-east-1
export AWS_ZONE=us-east-1a
docker-compose run -e constraint:node==swarm-master --rm provision playbooks/flocker-configure-agent.yml
```

At this point you should be able to create your very first Flocker volume. Let's test:

```
docker-machine ssh swarm-master
sudo bash
docker run -v apples:/data --volume-driver flocker busybox sh -c "echo hello > /data/file.txt"
```

which should produce the following output:

```
Unable to find image 'busybox:latest' locally
latest: Pulling from library/busybox
385e281300cc: Pull complete
a3ed95caeb02: Pull complete
Digest: sha256:4a887a2326ec9e0fa90cce7b4764b0e627b5d6afcb81a3f73c85dc29cea00048
Status: Downloaded newer image for busybox:latest
```

let's make sure the file is there after our container is gone:

```
docker run -v apples:/data --volume-driver flocker busybox sh -c "cat /data/file.txt"
```

which produces:

```
hello
```

Let's now add the ```swarm-node-01``` to our flocker cluster:

```
./copy-node-certifica.sh swarm-master swarm-node-01
docker-compose run -e constraint:node==swarm-node-01 --rm provision playbooks/flocker-configure-agent.yml
```

and test:

```
docker-machine ssh swarm-node-01
sudo bash
docker run -v apples:/data --volume-driver flocker busybox sh -c "cat /data/file.txt"
```

which should produce:

```
Unable to find image 'busybox:latest' locally
latest: Pulling from library/busybox
385e281300cc: Pull complete
a3ed95caeb02: Pull complete
Digest: sha256:4a887a2326ec9e0fa90cce7b4764b0e627b5d6afcb81a3f73c85dc29cea00048
Status: Downloaded newer image for busybox:latest
```

and then after the container is migrated from the Swarm master node to Node 01, you should see:

```
hello
```
