# save as: destroy-all.ps1
$REGION = "us-east-1"
$TF_DIR = "D:\Projects\ML_Pipeline\taxi-ml-infra\terraform\envs\dev"

Write-Host "`n=== STEP 1: Delete EFS Mount Targets ===" -ForegroundColor Cyan
$fsList = aws efs describe-file-systems `
  --query "FileSystems[*].FileSystemId" `
  --region $REGION --output text

if ($fsList -and $fsList -ne "None") {
    foreach ($fsId in $fsList.Split("`t")) {
        if (-not $fsId) { continue }
        Write-Host "Processing EFS: $fsId"
        $mts = aws efs describe-mount-targets `
          --file-system-id $fsId `
          --query "MountTargets[*].MountTargetId" `
          --region $REGION --output text
        foreach ($mt in $mts.Split("`t")) {
            if (-not $mt) { continue }
            Write-Host "  Deleting mount target: $mt"
            aws efs delete-mount-target --mount-target-id $mt --region $REGION
        }
    }
    Write-Host "Waiting 30s for ENIs to release..."
    Start-Sleep -Seconds 30
} else {
    Write-Host "No EFS filesystems found. Skipping."
}

Write-Host "`n=== STEP 2: Delete SageMaker Domain (if exists) ===" -ForegroundColor Cyan
$domainId = aws sagemaker list-domains `
  --region $REGION `
  --query "Domains[0].DomainId" `
  --output text

if ($domainId -and $domainId -ne "None") {
    Write-Host "Deleting SageMaker domain: $domainId"
    aws sagemaker delete-domain `
      --domain-id $domainId `
      --retention-policy HomeEfsFileSystem=Delete `
      --region $REGION
    Write-Host "Waiting 60s for SageMaker domain deletion..."
    Start-Sleep -Seconds 60
} else {
    Write-Host "No SageMaker domain found. Skipping."
}

Write-Host "`n=== STEP 3: Terraform Destroy ===" -ForegroundColor Cyan
cd $TF_DIR
terraform destroy -auto-approve

Write-Host "`n=== STEP 4: Check for Stuck VPC ===" -ForegroundColor Cyan
$vpcs = aws ec2 describe-vpcs `
  --filters "Name=tag:Project,Values=nyc-taxi" `
  --query "Vpcs[*].VpcId" `
  --region $REGION --output text

if ($vpcs -and $vpcs -ne "None") {
    foreach ($vpcId in $vpcs.Split("`t")) {
        if (-not $vpcId) { continue }
        Write-Host "Cleaning up stuck VPC: $vpcId"

        # Delete security groups
        $sgs = aws ec2 describe-security-groups `
          --filters "Name=vpc-id,Values=$vpcId" `
          --query "SecurityGroups[?GroupName!='default'].GroupId" `
          --region $REGION --output text
        foreach ($sg in $sgs.Split("`t")) {
            if (-not $sg) { continue }
            aws ec2 delete-security-group --group-id $sg --region $REGION 2>$null
        }

        # Delete route tables
        $rts = aws ec2 describe-route-tables `
          --filters "Name=vpc-id,Values=$vpcId" `
          --query "RouteTables[?Associations[0].Main!=true].RouteTableId" `
          --region $REGION --output text
        foreach ($rt in $rts.Split("`t")) {
            if (-not $rt) { continue }
            aws ec2 delete-route-table --route-table-id $rt --region $REGION 2>$null
        }

        # Detach and delete IGW
        $igw = aws ec2 describe-internet-gateways `
          --filters "Name=attachment.vpc-id,Values=$vpcId" `
          --query "InternetGateways[0].InternetGatewayId" `
          --region $REGION --output text
        if ($igw -and $igw -ne "None") {
            aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $vpcId --region $REGION 2>$null
            aws ec2 delete-internet-gateway --internet-gateway-id $igw --region $REGION 2>$null
        }

        # Delete VPC
        aws ec2 delete-vpc --vpc-id $vpcId --region $REGION
        Write-Host "VPC $vpcId deleted." -ForegroundColor Green
    }
} else {
    Write-Host "No stuck VPCs found." -ForegroundColor Green
}

Write-Host "`n=== ALL DONE ===" -ForegroundColor Green
Write-Host "All resources destroyed successfully!"