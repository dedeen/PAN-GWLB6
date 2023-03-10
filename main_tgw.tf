#  Terraform to create Transit GW (TGW), attachments in the VPCs, and TGW Route Tables
#   TGW:
resource "aws_ec2_transit_gateway" "TGW-PAN"  {
  description                         = "TGW-PAN"
  amazon_side_asn                     = 64512
  default_route_table_association     = "disable"
  default_route_table_propagation     = "disable"
  dns_support                         = "enable" 
  vpn_ecmp_support                    = "enable"
  tags = {
    Owner = "dan-via-terraform"
    Name  = "TGW-PAN"
  }
}

#  Route Table for Spoke VPCs
resource "aws_ec2_transit_gateway_route_table" "TGW-RT-Spoke-VPCs" {
  transit_gateway_id = aws_ec2_transit_gateway.TGW-PAN.id
  tags = {
    Owner = "dan-via-terraform"
    Name  = "TGW-RT-Spokes"
  }
}

#  Route Table for Security VPC
resource "aws_ec2_transit_gateway_route_table" "TGW-RT-Security-VPC" {
  transit_gateway_id = aws_ec2_transit_gateway.TGW-PAN.id
  tags = {
    Owner = "dan-via-terraform"
    Name  = "TGW-RT-Security-VPC"
  }
}

#  Create TGW Attachments in each of the VPCs
#  App01-VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "app1vpc-att" {
  subnet_ids              = [module.vpc["app1vpc"].intra_subnets[1],module.vpc["app1vpc"].intra_subnets[3]]
  transit_gateway_id      = aws_ec2_transit_gateway.TGW-PAN.id
  vpc_id                  = module.vpc["app1vpc"].vpc_id
  appliance_mode_support  = "enable"                            # prevents asymm flows between consumer VPC and security VPC
  dns_support             = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Owner = "dan-via-terraform"
    Name  = "TGW-app1vpc-att"
  }  
}

#  App02-VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "app2vpc-att" {
  subnet_ids              = [module.vpc["app2vpc"].intra_subnets[1],module.vpc["app2vpc"].intra_subnets[3]]
  transit_gateway_id      = aws_ec2_transit_gateway.TGW-PAN.id
  vpc_id                  = module.vpc["app2vpc"].vpc_id
  appliance_mode_support  = "enable"                            # prevents asymm flows between consumer VPC and security VPC
  dns_support             = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Owner = "dan-via-terraform"
    Name  = "TGW-app2vpc-att"
  }  
}
    
#  Mgmt-VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "mgmtvpc-att" {
  subnet_ids              = [module.vpc["mgmtvpc"].intra_subnets[2],module.vpc["mgmtvpc"].intra_subnets[5]]
  transit_gateway_id      = aws_ec2_transit_gateway.TGW-PAN.id
  vpc_id                  = module.vpc["mgmtvpc"].vpc_id
  appliance_mode_support  = "enable"                            # prevents asymm flows between consumer VPC and security VPC
  dns_support             = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Owner = "dan-via-terraform"
    Name  = "TGW-mgmtvpc-att"
  }  
}

#  Sec01-VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "secvpc-att" {
  subnet_ids              = [module.vpc["secvpc"].intra_subnets[3],module.vpc["secvpc"].intra_subnets[9]]
  transit_gateway_id      = aws_ec2_transit_gateway.TGW-PAN.id
  vpc_id                  = module.vpc["secvpc"].vpc_id
  appliance_mode_support  = "enable"                            # prevents asymm flows between consumer VPC and security VPC
  dns_support             = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Owner = "dan-via-terraform"
    Name  = "TGW-secvpc-att"
  }  
}
    
#  WebSrv VPC - placeholder until inbound traffic arch determined 
resource "aws_ec2_transit_gateway_vpc_attachment" "websrvvpc-dummy" {
  subnet_ids              = [module.vpc["websrvvpc"].intra_subnets[1],module.vpc["websrvvpc"].intra_subnets[4]]
  transit_gateway_id      = aws_ec2_transit_gateway.TGW-PAN.id
  vpc_id                  = module.vpc["websrvvpc"].vpc_id
  appliance_mode_support  = "enable"                            # prevents asymm flows between consumer VPC and security VPC
  dns_support             = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Owner = "dan-via-terraform"
    Name  = "TGW-websrvvpc-DUMMY-att"
  }  
}

#  Associate spokes route table with app1vpc TGW attachment
 resource "aws_ec2_transit_gateway_route_table_association" "spoke-to-app1vpc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app1vpc-att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-RT-Spoke-VPCs.id
}
    
#  Associate spokes route table with app2vpc TGW attachment
 resource "aws_ec2_transit_gateway_route_table_association" "spoke-to-app2vpc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app2vpc-att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-RT-Spoke-VPCs.id
}
    
 #  Associate spokes route table with mgmtvpc TGW attachment
 resource "aws_ec2_transit_gateway_route_table_association" "spoke-to-mgmtvpc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.mgmtvpc-att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-RT-Spoke-VPCs.id
}
  
 #  Associate security route table with the security vpc TGW attachment
 resource "aws_ec2_transit_gateway_route_table_association" "sec-rt-to-secvpc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.secvpc-att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-RT-Security-VPC.id
}
    
#  Propagate routes from app1vpc TGW attachment to the route table for the security vpc
resource "aws_ec2_transit_gateway_route_table_propagation" "app1vpc-to-sec-rt" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app1vpc-att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-RT-Security-VPC.id
}
    
#  Propagate routes from app2vpc TGW attachment to the route table for the security vpc
resource "aws_ec2_transit_gateway_route_table_propagation" "app2vpc-to-sec-rt" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app2vpc-att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-RT-Security-VPC.id
}
    
#  Propagate routes from mgmtvpc TGW attachment to the route table for the security vpc
resource "aws_ec2_transit_gateway_route_table_propagation" "mgmtvpc-to-sec-rt" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.mgmtvpc-att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-RT-Security-VPC.id
}

#  Propagate routes from >> security VPC to the security_route_table
resource "aws_ec2_transit_gateway_route_table_propagation" "secvpc-to-sec-rt" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.secvpc-att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-RT-Security-VPC.id
}
#  Propagate routes from >> security VPC to the spokes_route_table
resource "aws_ec2_transit_gateway_route_table_propagation" "secvpc-to-spokes-rt" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.secvpc-att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-RT-Spoke-VPCs.id
}
 
#  Add default route to TGW spokes RT to direct all traffic to the security VPC
resource "aws_ec2_transit_gateway_route" "spokes-def-route-via-TGW" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.secvpc-att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-RT-Spoke-VPCs.id
}   
    
