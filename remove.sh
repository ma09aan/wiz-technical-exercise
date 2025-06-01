#!/bin/bash

REGION="us-east-1"  # Change region if needed

vpcs=$(aws ec2 describe-vpcs --region $REGION --query "Vpcs[?IsDefault==\`false\`].VpcId" --output text)

for vpc_id in $vpcs; do
  echo "Deleting VPC: $vpc_id"

  # Detach and delete internet gateways
  igws=$(aws ec2 describe-internet-gateways --region $REGION --filters Name=attachment.vpc-id,Values=$vpc_id --query "InternetGateways[].InternetGatewayId" --output text)
  for igw in $igws; do
    aws ec2 detach-internet-gateway --region $REGION --internet-gateway-id $igw --vpc-id $vpc_id
    aws ec2 delete-internet-gateway --region $REGION --internet-gateway-id $igw
  done

  # Delete subnets
  subnets=$(aws ec2 describe-subnets --region $REGION --filters Name=vpc-id,Values=$vpc_id --query "Subnets[].SubnetId" --output text)
  for subnet in $subnets; do
    aws ec2 delete-subnet --region $REGION --subnet-id $subnet
  done

  # Delete route tables (excluding the main one, which is auto-deleted with the VPC)
  rtbs=$(aws ec2 describe-route-tables --region $REGION --filters Name=vpc-id,Values=$vpc_id --query "RouteTables[].RouteTableId" --output text)
  for rtb in $rtbs; do
    main=$(aws ec2 describe-route-tables --region $REGION --route-table-ids $rtb --query "RouteTables[0].Associations[0].Main" --output text)
    if [[ "$main" != "true" ]]; then
      aws ec2 delete-route-table --region $REGION --route-table-id $rtb
    fi
  done

  # Delete security groups (except the default one)
  sgs=$(aws ec2 describe-security-groups --region $REGION --filters Name=vpc-id,Values=$vpc_id --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
  for sg in $sgs; do
    aws ec2 delete-security-group --region $REGION --group-id $sg
  done

  # Delete network ACLs (except the default one)
  acls=$(aws ec2 describe-network-acls --region $REGION --filters Name=vpc-id,Values=$vpc_id --query "NetworkAcls[?IsDefault==\`false\`].NetworkAclId" --output text)
  for acl in $acls; do
    aws ec2 delete-network-acl --region $REGION --network-acl-id $acl
  done

  # Delete NAT gateways
  natgws=$(aws ec2 describe-nat-gateways --region $REGION --filter Name=vpc-id,Values=$vpc_id --query "NatGateways[].NatGatewayId" --output text)
  for natgw in $natgws; do
    aws ec2 delete-nat-gateway --region $REGION --nat-gateway-id $natgw
    echo "Waiting for NAT gateway $natgw to be deleted..."
    aws ec2 wait nat-gateway-deleted --region $REGION --nat-gateway-ids $natgw
  done

  # Delete VPC peering connections
  peerings=$(aws ec2 describe-vpc-peering-connections --region $REGION --filters Name=requester-vpc-info.vpc-id,Values=$vpc_id --query "VpcPeeringConnections[].VpcPeeringConnectionId" --output text)
  for p in $peerings; do
    aws ec2 delete-vpc-peering-connection --region $REGION --vpc-peering-connection-id $p
  done

  # Finally, delete the VPC
  aws ec2 delete-vpc --region $REGION --vpc-id $vpc_id
  echo "VPC $vpc_id deleted."
done

