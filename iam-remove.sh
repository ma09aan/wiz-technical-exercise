#!/bin/bash

# List and delete IAM roles with "wiz" in the name
for role in $(aws iam list-roles --query "Roles[?contains(RoleName, \`wiz\`)].RoleName" --output text); do
  echo "Deleting IAM role: $role"

  # Detach managed policies
  for policy_arn in $(aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text); do
    echo " Detaching policy: $policy_arn"
    aws iam detach-role-policy --role-name "$role" --policy-arn "$policy_arn"
  done

  # Delete inline policies
  for inline_policy in $(aws iam list-role-policies --role-name "$role" --query 'PolicyNames[]' --output text); do
    echo " Deleting inline policy: $inline_policy"
    aws iam delete-role-policy --role-name "$role" --policy-name "$inline_policy"
  done

  # Delete the role
  aws iam delete-role --role-name "$role"
done

# List and delete customer-managed IAM policies with "wiz" in the name
for policy_arn in $(aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, \`wiz\`)].Arn" --output text); do
  echo "Deleting IAM policy: $policy_arn"

  # Delete all non-default versions first
  for version in $(aws iam list-policy-versions --policy-arn "$policy_arn" --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text); do
    echo " Deleting policy version: $version"
    aws iam delete-policy-version --policy-arn "$policy_arn" --version-id "$version"
  done

  # Now delete the policy itself
  aws iam delete-policy --policy-arn "$policy_arn"
done

