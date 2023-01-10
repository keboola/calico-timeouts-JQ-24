
# Infrastructure Setup

## Prerequisities
- AWS account
- AWS cli v2
- Terraform ^1.3
- kubectl

## Deployment
Following script will provision AWS VPC and EKS cluster into provided AWS account.

```
# Your AWS profile with AdministratorAccess permissions
export AWS_PROFILE=xxx 

terraform init
terraform apply
```

Configure kubectl so that you can connect to an Amazon EKS cluster.
```
aws eks --region eu-central-1 update-kubeconfig --name keboola-calico-timeouts-JQ-24
```

Install Calico CNI:
```
./deploy-calico.sh

# Replace nodes
aws autoscaling  start-instance-refresh --region eu-central-1 --auto-scaling-group-name=$(terraform output --raw autoscaling_group_name) --strategy Rolling
```

Verify that system pods are running. It should provide similar output:
```
kubectl get pods --all-namespaces -o wide
NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE   IP            NODE                                          NOMINATED NODE   READINESS GATES
kube-system   calico-kube-controllers-7b8458594b-xkbbq   1/1     Running   0          10m   100.64.72.3   ip-10-0-3-238.eu-central-1.compute.internal   <none>           <none>
kube-system   calico-node-8wql6                          1/1     Running   0          93s   10.0.3.238    ip-10-0-3-238.eu-central-1.compute.internal   <none>           <none>
kube-system   coredns-79cbbf8cb-ngklm                    1/1     Running   0          10m   100.64.72.1   ip-10-0-3-238.eu-central-1.compute.internal   <none>           <none>
kube-system   coredns-79cbbf8cb-r22rq                    1/1     Running   0          10m   100.64.72.2   ip-10-0-3-238.eu-central-1.compute.internal   <none>           <none>
kube-system   kube-proxy-9c8jw                           1/1     Running   0          93s   10.0.3.238    ip-10-0-3-238.eu-central-1.compute.internal   <none>           <none>
```

## Cleanup

To destroy all provisioned AWS resources:
```
terraform destroy
```