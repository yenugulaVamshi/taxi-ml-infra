# ============================================================
# destroy-all.ps1
# One-command teardown for NYC Taxi ML Pipeline
# Usage: .\destroy-all.ps1
# ============================================================

$REGION = "us-east-1"
$TF_DIR = "D:\Projects\ML_Pipeline\taxi-ml-infra\terraform\envs\dev"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "   NYC TAXI ML PIPELINE - FULL INFRASTRUCTURE TEARDOWN" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# STEP 1: Delete EFS Mount Targets
# Must run before terraform destroy.
# EFS mount targets create ENIs that block subnet deletion.
# ============================================================
Write-Host "=== STEP 1: Delete EFS Mount Targets ===" -ForegroundColor Cyan

$fsList = aws efs describe-file-systems --query "FileSystems[*].FileSystemId" --region $REGION --output text

if ($fsList -and $fsList -ne "None" -and $fsList.Trim() -ne "") {
    foreach ($fsId in $fsList.Split("`t")) {
        if (-not $fsId -or $fsId.Trim() -eq "") { continue }
        Write-Host "  Processing EFS: $fsId"
        $mts = aws efs describe-mount-targets --file-system-id $fsId --query "MountTargets[*].MountTargetId" --region $REGION --output text
        if ($mts -and $mts -ne "None" -and $mts.Trim() -ne "") {
            foreach ($mt in $mts.Split("`t")) {
                if (-not $mt -or $mt.Trim() -eq "") { continue }
                Write-Host "    Deleting mount target: $mt"
                aws efs delete-mount-target --mount-target-id $mt --region $REGION
            }
            Write-Host "  Waiting 30s for ENIs to release..."
            Start-Sleep -Seconds 30
        }
    }
} else {
    Write-Host "  No EFS filesystems found. Skipping." -ForegroundColor Gray
}

Write-Host ""

# ============================================================
# STEP 2: Delete SageMaker Apps, User Profiles, and Domain
# Order matters: Apps -> Profiles -> Domain
# Domain must be deleted with HomeEfsFileSystem=Delete
# ============================================================
Write-Host "=== STEP 2: Delete SageMaker Domains ===" -ForegroundColor Cyan

$domains = aws sagemaker list-domains --region $REGION --query "Domains[*].DomainId" --output text

if ($domains -and $domains -ne "None" -and $domains.Trim() -ne "") {
    foreach ($domainId in $domains.Split("`t")) {
        if (-not $domainId -or $domainId.Trim() -eq "") { continue }
        Write-Host "  Found domain: $domainId"

        $profiles = aws sagemaker list-user-profiles --domain-id $domainId --region $REGION --query "UserProfiles[*].UserProfileName" --output text

        if ($profiles -and $profiles -ne "None" -and $profiles.Trim() -ne "") {
            foreach ($profile in $profiles.Split("`t")) {
                if (-not $profile -or $profile.Trim() -eq "") { continue }

                $apps = aws sagemaker list-apps --domain-id $domainId --user-profile-name $profile --region $REGION --query "Apps[?Status!='Deleted'].{Name:AppName,Type:AppType}" --output text 2>$null
                if ($apps -and $apps.Trim() -ne "") {
                    foreach ($appLine in $apps.Split("`n")) {
                        $parts = $appLine.Trim().Split("`t")
                        if ($parts.Count -lt 2) { continue }
                        $appName = $parts[0].Trim()
                        $appType = $parts[1].Trim()
                        if (-not $appName -or $appName -eq "") { continue }
                        Write-Host "    Deleting app: $appName ($appType)"
                        aws sagemaker delete-app --domain-id $domainId --user-profile-name $profile --app-name $appName --app-type $appType --region $REGION 2>$null
                    }
                    Write-Host "    Waiting 20s for apps to stop..."
                    Start-Sleep -Seconds 20
                }

                Write-Host "    Deleting profile: $profile"
                aws sagemaker delete-user-profile --domain-id $domainId --user-profile-name $profile --region $REGION

                $timeout = 0
                while ($true) {
                    $status = aws sagemaker describe-user-profile --domain-id $domainId --user-profile-name $profile --region $REGION --query "Status" --output text 2>$null
                    if (-not $status -or $status.Trim() -eq "" -or $status -eq "None") { Write-Host "    Profile deleted." -ForegroundColor Green; break }
                    if ($status -eq "Delete_Failed") { Write-Host "    Profile deletion FAILED." -ForegroundColor Red; break }
                    Write-Host "    Status: $status - waiting..."
                    Start-Sleep -Seconds 10
                    $timeout += 10
                    if ($timeout -gt 300) { Write-Host "    Timed out." -ForegroundColor Red; break }
                }
            }
        }

        Write-Host "  Deleting domain: $domainId"
        aws sagemaker delete-domain --domain-id $domainId --retention-policy HomeEfsFileSystem=Delete --region $REGION

        $timeout = 0
        while ($true) {
            $status = aws sagemaker describe-domain --domain-id $domainId --region $REGION --query "Status" --output text 2>$null
            if (-not $status -or $status.Trim() -eq "" -or $status -eq "None") { Write-Host "  Domain deleted." -ForegroundColor Green; break }
            if ($status -eq "Delete_Failed") { Write-Host "  Domain deletion FAILED." -ForegroundColor Red; break }
            Write-Host "  Status: $status - waiting..."
            Start-Sleep -Seconds 15
            $timeout += 15
            if ($timeout -gt 600) { Write-Host "  Timed out." -ForegroundColor Red; break }
        }
    }
} else {
    Write-Host "  No SageMaker domains found. Skipping." -ForegroundColor Gray
}

Write-Host ""

# ============================================================
# STEP 3: Terraform Destroy
# ============================================================
Write-Host "=== STEP 3: Terraform Destroy ===" -ForegroundColor Cyan
Set-Location $TF_DIR
terraform destroy -auto-approve

Write-Host ""

# ============================================================
# STEP 4: VPC Safety Net
# Finds stuck VPCs tagged Project=nyc-taxi and force-cleans them.
# Uses .NET file writing to avoid PowerShell UTF-8 BOM issues
# that cause AWS CLI JSON parsing errors.
# ============================================================
Write-Host "=== STEP 4: VPC Safety Net Cleanup ===" -ForegroundColor Cyan

$vpcs = aws ec2 describe-vpcs --filters "Name=tag:Project,Values=nyc-taxi" --query "Vpcs[*].VpcId" --region $REGION --output text

if ($vpcs -and $vpcs -ne "None" -and $vpcs.Trim() -ne "") {
    foreach ($vpcId in $vpcs.Split("`t")) {
        if (-not $vpcId -or $vpcId.Trim() -eq "") { continue }
        Write-Host "  Found stuck VPC: $vpcId - cleaning up..."

        # -- Get all non-default security groups --
        $sgs = aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpcId" --query "SecurityGroups[?GroupName!='default'].GroupId" --region $REGION --output text

        if ($sgs -and $sgs.Trim() -ne "") {
            foreach ($sg in $sgs.Split("`t")) {
                if (-not $sg -or $sg.Trim() -eq "") { continue }

                # Get ingress rules as JSON and write to file WITHOUT BOM
                $ingress = aws ec2 describe-security-groups --group-ids $sg --query "SecurityGroups[0].IpPermissions" --region $REGION --output json
                if ($ingress -and $ingress.Trim() -ne "[]" -and $ingress.Trim() -ne "null") {
                    $tmpFile = "$env:TEMP\sg-ingress-$sg.json"
                    [System.IO.File]::WriteAllText($tmpFile, $ingress)
                    Write-Host "    Revoking ingress: $sg"
                    aws ec2 revoke-security-group-ingress --group-id $sg --region $REGION --ip-permissions file://$tmpFile 2>$null
                }

                # Get egress rules as JSON and write to file WITHOUT BOM
                $egress = aws ec2 describe-security-groups --group-ids $sg --query "SecurityGroups[0].IpPermissionsEgress" --region $REGION --output json
                if ($egress -and $egress.Trim() -ne "[]" -and $egress.Trim() -ne "null") {
                    $tmpFile = "$env:TEMP\sg-egress-$sg.json"
                    [System.IO.File]::WriteAllText($tmpFile, $egress)
                    Write-Host "    Revoking egress: $sg"
                    aws ec2 revoke-security-group-egress --group-id $sg --region $REGION --ip-permissions file://$tmpFile 2>$null
                }
            }

            # Now delete all security groups
            foreach ($sg in $sgs.Split("`t")) {
                if (-not $sg -or $sg.Trim() -eq "") { continue }
                Write-Host "    Deleting SG: $sg"
                aws ec2 delete-security-group --group-id $sg --region $REGION 2>$null
            }
        }

        # -- Delete non-main route tables --
        $rts = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpcId" --query "RouteTables[?Associations[0].Main!=true].RouteTableId" --region $REGION --output text
        if ($rts -and $rts.Trim() -ne "") {
            foreach ($rt in $rts.Split("`t")) {
                if (-not $rt -or $rt.Trim() -eq "") { continue }
                Write-Host "    Deleting RT: $rt"
                aws ec2 delete-route-table --route-table-id $rt --region $REGION 2>$null
            }
        }

        # -- Detach and delete Internet Gateway --
        $igw = aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpcId" --query "InternetGateways[0].InternetGatewayId" --region $REGION --output text
        if ($igw -and $igw -ne "None" -and $igw.Trim() -ne "") {
            Write-Host "    Detaching IGW: $igw"
            aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $vpcId --region $REGION 2>$null
            aws ec2 delete-internet-gateway --internet-gateway-id $igw --region $REGION 2>$null
        }

        # -- Delete remaining subnets --
        $subnets = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpcId" --query "Subnets[*].SubnetId" --region $REGION --output text
        if ($subnets -and $subnets.Trim() -ne "") {
            foreach ($subnet in $subnets.Split("`t")) {
                if (-not $subnet -or $subnet.Trim() -eq "") { continue }
                Write-Host "    Deleting subnet: $subnet"
                aws ec2 delete-subnet --subnet-id $subnet --region $REGION 2>$null
            }
        }

        # -- Delete VPC --
        Write-Host "  Deleting VPC: $vpcId"
        aws ec2 delete-vpc --vpc-id $vpcId --region $REGION
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  VPC $vpcId deleted!" -ForegroundColor Green
        } else {
            Write-Host "  VPC $vpcId still blocked. Remaining resources:" -ForegroundColor Red
            aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$vpcId" --query "NetworkInterfaces[*].{ID:NetworkInterfaceId,Status:Status,Desc:Description}" --region $REGION --output table
            aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpcId" --query "SecurityGroups[?GroupName!='default'].{ID:GroupId,Name:GroupName}" --region $REGION --output table
        }
    }
} else {
    Write-Host "  No stuck VPCs found. Destroy was clean." -ForegroundColor Green
}

# -- Clean up temp JSON files --
Remove-Item "$env:TEMP\sg-*.json" -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "   ALL DONE - Infrastructure fully destroyed" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "To rebuild: cd terraform\envs\dev && terraform apply -auto-approve" -ForegroundColor White
Write-Host ""
