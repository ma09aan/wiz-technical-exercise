#!/bin/bash

set -e

REGION="us-east-1"
echo "Starting full VPC and resource cleanup in region $REGION..."

# Remove all EKS clusters
eks_clusters=$(aws eks list-clusters --region $REGION --query "clusters[]" --output text)
for cluster in $eks_clusters; do
  echo "Deleting nodegroups for EKS cluster: $cluster"
  nodegroups=$(aws eks list-nodegroups --region $REGION --cluster-name $cluster --query "nodegroups[]" --output text)
  for nodegroup in $nodegroups; do
    echo "Deleting nodegroup: $nodegroup"
    aws eks delete-nodegroup --region $REGION --cluster-name $cluster --nodegroup-name $nodegroup
  done

  # Wait for all nodegroups to be deleted before deleting cluster
  while true; do
    remaining_nodegroups=$(aws eks list-nodegroups --region $REGION --cluster-name $cluster --query "nodegroups[]" --output text)
    if [ -z "$remaining_nodegroups" ]; then
      break
    fi
    echo "Waiting for nodegroups to be deleted..."
    sleep 15
  done

  echo "Deleting EKS cluster: $cluster"
  aws eks delete-cluster --region $REGION --name $cluster
done

# Get all non-default VPCs
vpcs=$(aws ec2 describe-vpcs --region $REGION --query "Vpcs[?IsDefault==\`false\`].VpcId" --output text)

for vpc_id in $vpcs; do
  echo "Cleaning up VPC: $vpc_id"

  # Terminate EC2 instances
  instances=$(aws ec2 describe-instances --region $REGION --filters Name=vpc-id,Values=$vpc_id --query "Reservations[].Instances[].InstanceId" --output text)
  if [[ -n "$instances" ]]; then
    aws ec2 terminate-instances --region $REGION --instance-ids $instances
    echo "Waiting for EC2 instances to terminate..."
    aws ec2 wait instance-terminated --region $REGION --instance-ids $instances
  fi

  # Delete NAT Gateways
  natgws=$(aws ec2 describe-nat-gateways --region $REGION --filter Name=vpc-id,Values=$vpc_id --query "NatGateways[].NatGatewayId" --output text)
  for natgw in $natgws; do
    aws ec2 delete-nat-gateway --region $REGION --nat-gateway-id $natgw
    echo "Waiting for NAT gateway $natgw to be deleted..."
    aws ec2 wait nat-gateway-deleted --region $REGION --nat-gateway-ids $natgw
  done

  # Delete load balancers
  lbs=$(aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?VpcId=='$vpc_id'].LoadBalancerArn" --output text)
  for lb in $lbs; do
    echo "Deleting Load Balancer: $lb"
    aws elbv2 delete-load-balancer --region $REGION --load-balancer-arn $lb
  done

  # Delete target groups
  tgs=$(aws elbv2 describe-target-groups --region $REGION --query "TargetGroups[?VpcId=='$vpc_id'].TargetGroupArn" --output text)
  for tg in $tgs; do
    echo "Deleting Target Group: $tg"
    aws elbv2 delete-target-group --region $REGION --target-group-arn $tg
  done

  # Delete VPC endpoints
  endpoints=$(aws ec2 describe-vpc-endpoints --region $REGION --filters Name=vpc-id,Values=$vpc_id --query "VpcEndpoints[].VpcEndpointId" --output text)
  for ep in $endpoints; do
    aws ec2 delete-vpc-endpoints --region $REGION --vpc-endpoint-ids $ep
  done

  # Release and delete EIPs
  eips=$(aws ec2 describe-addresses --region $REGION --query "Addresses[?VpcId=='$vpc_id'].AllocationId" --output text)
  for eip in $eips; do
    aws ec2 release-address --region $REGION --allocation-id $eip
  done

  # Delete ENIs
  enis=$(aws ec2 describe-network-interfaces --region $REGION --filters Name=vpc-id,Values=$vpc_id --query "NetworkInterfaces[].NetworkInterfaceId" --output text)
  for eni in $enis; do
    aws ec2 delete-network-interface --region $REGION --network-interface-id $eni || echo "Couldn't delete ENI: $eni"
  done

  # Delete custom security groups
  sgs=$(aws ec2 describe-security-groups --region $REGION --filters Name=vpc-id,Values=$vpc_id --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
  for sg in $sgs; do
    aws ec2 delete-security-group --region $REGION --group-id $sg || echo "Couldn't delete SG: $sg"
  done

  # Delete route tables
  rtbs=$(aws ec2 describe-route-tables --region $REGION --filters Name=vpc-id,Values=$vpc_id --query "RouteTables[].RouteTableId" --output text)
  for rtb in $rtbs; do
    main=$(aws ec2 describe-route-tables --region $REGION --route-table-ids $rtb --query "RouteTables[0].Associations[0].Main" --output text)
    if [[ "$main" != "true" ]]; then
      aws ec2 delete-route-table --region $REGION --route-table-id $rtb
    fi
  done

  # Detach and delete internet gateways
  igws=$(aws ec2 describe-internet-gateways --region $REGION --filters Name=attachment.vpc-id,Values=$vpc_id --query "InternetGateways[].InternetGatewayId" --output text)
  for igw in $igws; do
    aws ec2 detach-internet-gateway --region $REGION --internet-gateway-id $igw --vpc-id $vpc_id
    aws ec2 delete-internet-gateway --region $REGION --internet-gateway-id $igw
  done

  # Delete subnets
  subnets=$(aws ec2 describe-subnets --region $REGION --filters Name=vpc-id,Values=$vpc_id --query "Subnets[].SubnetId" --output text)
  for subnet in $subnets; do
    aws ec2 delete-subnet --region $REGION --subnet-id $subnet || echo "Subnet still in use: $subnet"
  done

  # Delete non-default NACLs
  acls=$(aws ec2 describe-network-acls --region $REGION --filters Name=vpc-id,Values=$vpc_id --query "NetworkAcls[?IsDefault==\`false\`].NetworkAclId" --output text)
  for acl in $acls; do
    aws ec2 delete-network-acl --region $REGION --network-acl-id $acl
  done

  # Delete VPC peering
  peerings=$(aws ec2 describe-vpc-peering-connections --region $REGION --filters Name=requester-vpc-info.vpc-id,Values=$vpc_id --query "VpcPeeringConnections[].VpcPeeringConnectionId" --output text)
  for p in $peerings; do
    aws ec2 delete-vpc-peering-connection --region $REGION --vpc-peering-connection-id $p
  done

  # Finally delete VPC
  aws ec2 delete-vpc --region $REGION --vpc-id $vpc_id
  echo "✅ VPC $vpc_id deleted."
done

# Delete IAM roles and policies with "wiz" in name
echo "Cleaning up IAM roles and policies with 'wiz' prefix/suffix..."
roles=$(aws iam list-roles --query "Roles[?contains(RoleName, 'wiz')].RoleName" --output text)
for role in $roles; do
  echo "Deleting role: $role"
  attached_policies=$(aws iam list-attached-role-policies --role-name $role --query "AttachedPolicies[].PolicyArn" --output text)
  for pol in $attached_policies; do
    aws iam detach-role-policy --role-name $role --policy-arn $pol
  done
  inline_policies=$(aws iam list-role-policies --role-name $role --query "PolicyNames[]" --output text)
  for inline in $inline_policies; do
    aws iam delete-role-policy --role-name $role --policy-name $inline
  done
  aws iam delete-role --role-name $role
done

# Delete customer-managed policies with "wiz"
custom_policies=$(aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, 'wiz')].Arn" --output text)
for pol in $custom_policies; do
  echo "Deleting IAM policy: $pol"
  aws iam delete-policy --policy-arn $pol
done

echo "🎉 All clean!"

