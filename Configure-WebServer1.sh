#########################################################################
#### This script provisions the web servers that are inside the webserver subnets. The only access to these hosts 
#       is either through the Palo Alto Firewall in the Security VPC, or locally from within the VPC. 
# 
#       As the EC2s are deployed from AWS Linux AMIs, they do not have the packages and configuration needed 
#       for web servers. 
#
#       This script will convert them into web servers as follows: 
#         1. Create a temporary IGW in the WebServer VPC 
#         2. Create a temporary ENI, attach it to the soon-to-be web serving EC2s
#         3. Map a public IP to the ENI, with route to the Internet through the IGW
#
#       Now that we have useful access to the EC2s, we perform the following steps:
#         4. SSH to the EC2 with the keypair generated by Terraform upon instance creation
#         5. Update the packages on linux, install and configure a LAMP stack, set the system up to run Apache upon restart
#              5a. "sudo amazon-linux-extras install php8.0 mariadb10.5 -y", 
#                   "sudo yum install -y httpd",
#                   "sudo systemctl start httpd",
#                   "sudo systemctl enable httpd"]
#
#         6. Wait a minute for the software and network to coalesce 
#         7. Test the webserver via curl to retrieve the Apache default test page
# 
#      Put things into production order: 
#         8. Disassociate the ENI from the webserver 
#         9. Disassociate the IGW from the WebServer VPC
#        10. Remove the temporary routes from EC2 to Internet via IGW


#################

# Set up some variables (ws == webserver host)
debug_flag=1                  #0: run straight through script, 1: pause and prompt during script run

ws_keypair=temp-replace-before-running-script
ws_inst_name=WebSrv1-az1
ws_subnet=websrv-az1-inst
ws_subnet_private_ip="10.110.0.30"
ws_loginid=ec2-user
igw_name=temp-igw

#Common vars 
bh_AMI=ami-094125af156557ca2
bh_type=t2.micro
bh_keypair=bastion-keypair
open_sec_group=SG-allow_ipv4

# Get some info from AWS for the target webserver
subnetid=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=${ws_subnet}" --query "Subnets[*].SubnetId" --output text)
vpcid=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=${ws_subnet}" --query "Subnets[*].VpcId" --output text)
cidr=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=${ws_subnet}" --query "Subnets[*].CidrBlock" --output text)
echo "SubnetId:"${subnetid}
echo "VpcId:"${vpcid}
echo "CIDR:"${cidr}

      #~~~
      if [ $debug_flag -eq 1 ]
         then read -p "___Paused, enter to proceed___"
      fi
      #~~~

#Build an IGW so we can access the web server from the outside -  just for initial configuration
#>>igwid=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text)
#>>echo "IGW:"${igwid}
#>>aws ec2 create-tags --resources $igwid --tags Key=Name,Value=${igw_name}

# Attach the bastion IGW to the bastion subnet's VPC 
#>>aws ec2 attach-internet-gateway --internet-gateway-id ${igwid} --vpc-id ${vpcid}

      #~~~
      if [ $debug_flag -eq 1 ]
         then read -p "___Paused, enter to proceed___"
      fi
      #~~~


# Get the handle for the web server EC2 - filter on running to avoid picking up previously terminated instances with same name
instid=$(aws ec2 describe-instances --filters Name=tag:Name,Values=${ws_inst_name} "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].InstanceId" --output text)
echo "Web Server identified:"${ws_inst_name}", InstanceID:"${instid}

# Create a network interface in the webserver's subnet with a public IP - to associate with the IGW
#eni=$(aws ec2 create-network-interface --description "Temp public IP to configure web server" --subnet-id ${subnetid} --query "NetworkInterface[*].NetworkInterfaceId" --output text)
eniid=$(aws ec2 create-network-interface --description "Temp public IP to configure web server" --subnet-id ${subnetid} --query "Attachment[*].AttachmentId" --output text)
echo "ENI Created:"${eniid}
exit 0 

# Get the security group in the target VPC that is wide open for IPv4, name referenced above
secgroupid=$(aws ec2 describe-security-groups --filters Name=group-name,Values=${open_sec_group} Name=vpc-id,Values=${vpcid} --query "SecurityGroups[*].GroupId" --output text)
echo "secgrp:"${secgroupid}

# Launch an EC2 that will be a bastion host into the VPC
instid=$(aws ec2 run-instances --image-id ${bh_AMI} --instance-type ${bh_type} --subnet-id ${subnetid} --key-name ${bh_keypair} --security-group-ids ${secgroupid} --associate-public-ip-address --query "Instances[*].InstanceId" --output text)
echo "InstanceID:"${instid}
aws ec2 create-tags --resources $instid --tags Key=Name,Value=${bh_ec2_name}

# Get the public & private IPs of the bastion host
publicip=$(aws ec2 describe-instances --instance-ids ${instid} --query "Reservations[*].Instances[*].PublicIpAddress" --output text)
echo "PublicIP:"${publicip}
privateip=$(aws ec2 describe-instances --instance-ids ${instid} --query "Reservations[*].Instances[*].PrivateIpAddress" --output text)
echo "PrivateIP:"${privateip}

      #~~~
      if [ $debug_flag -eq 1 ]
         then read -p "___Paused, enter to proceed___"
      fi
      #~~~
      
# Create a route table for the bastion subnet with a default route to the new IGW
#   This couldn't be created when VPC was built as bastion IGW didn't exist yet 

# Create RT
rtid=$(aws ec2 create-route-table --vpc-id ${vpcid} --query "RouteTable.RouteTableId" --output text)
echo "Route Table for Bastion Subnet:"${rtid}
aws ec2 create-tags --resources $rtid --tags Key=Name,Value=${bh_rt_name}

# Add default route
routesuccess=$(aws ec2 create-route --route-table-id ${rtid} --destination-cidr-block 0.0.0.0/0 --gateway-id ${igwid})
echo "Successfully created route?:"${routesuccess}

      #~~~
      if [ $debug_flag -eq 1 ]
         then read -p "___Paused, enter to proceed___"
      fi
      #~~~

# Associate to bastion subnet 
# Get RT ID for RT currently associated to the bastion subnet
orRT=$bh_vpc_name
targRT=$bh_rt_name
subnet1=$subnetid

rt0=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=${orRT}" --query "RouteTables[*].RouteTableId"  --output text)
rt1=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=${targRT}" --query "RouteTables[*].RouteTableId"  --output text)

# Get association ID for this route table
awscmd1="aws ec2 describe-route-tables --route-table-ids ${rt0} --filters \"Name=association.subnet-id,Values=${subnet1}\" --query \"RouteTables[*].Associations[?SubnetId=='${subnet1}']\"  --output text"
result1=$(eval "$awscmd1")

if [ "$result1" = "" ];
then
   # Empty string returned, so no rt association to change for this row
   result1="Not_Applicable: No_work_to_perform . . . . . "
   # echo "Empty String Returned"
 fi 
    
echo "AWSCLI Query Results->"${result1}
# Store the resource IDs from AWS in 4 arrays, parse them and store into the arrays with sync'ed indices
rtbassoc=$(cut -d " " -f 2 <<<$result1)
currrtb=$(cut -d " " -f 3 <<<$result1)
currsubnet=$(cut -d " " -f 4 <<<$result1)
awsrtnew=$rt1

awsrtcmd="aws ec2 replace-route-table-association --association-id ${rtbassoc} --route-table-id ${awsrtnew} --no-cli-auto-prompt --output text"
echo "... Sending this AWS CLI cmd:"
echo $awsrtcmd

      #~~~
      if [ $debug_flag -eq 1 ]
         then read -p "___Paused, enter to proceed___"
      fi
      #~~~

result2=$(eval "$awsrtcmd")
echo "... Returned results:"$result2

# All done now
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "| Bastion host deployed, IGW & routes added"
echo "|     Public IP: " ${publicip}
echo "|     Private IP: " ${privateip}
echo "|     ssh key:   " ${bh_keypair}".pem"
echo "| Wait a few minutes for EC2 to initialize"
echo "|     ssh ec2-user@"${publicip}" -i "${bh_keypair}".pem"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
exit 0
