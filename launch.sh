#!/bin/bash

#./cleanup.sh

#declare a variable

declare -a instanceARR

mapfile -t instanceARR < <(aws ec2 run-instances --image-id ami-d05e75b8 --count 2 --instance-type t2.micro --key-name ITMO544-Fall2015-VirtualBox --security-group-id sg-18b4bc7f --subnet-id subnet-5e540975 --associate-public-ip-address --iam-instance-profile Name=PHPDeveloperRole --user-data file:///home/controller/ITMO544-Fall-EnvSetup-MP1/install-env.sh --output table | grep InstanceId | sed "s/|//g" | tr -d ' ' | sed "s/InstanceId//g")

#aws ec2 run-instances --image-id ami-d05e75b8 --count 2 --instance-type t2.micro --key-name ITMO544-Fall2015-VirtualBox --security-group-id sg-18b4bc7f --subnet-id subnet-5e540975 --associate-public-ip-address --user-data file:///home/controller/ITMO544-Fall-EnvSetup-MP1/install-env.sh --debug
echo ${instanceARR[@]}

aws ec2 wait instance-running --instance-ids ${instanceARR[@]}
echo "instances are running"

ELBURL= (`aws elb create-load-balancer --load-balancer-name itmo544SKelb --listeners Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80 --security-groups sg-18b4bc7f --subnets subnet-5e540975 --output=text`);
echo $ELBURL
#echo -e "\n Finished launching ELB and sleeping 25 seconds"
#for i in {0..25}; do echo -ne '.'; sleep 1;done
#echo "\n"

aws elb register-instances-with-load-balancer --load-balancer-name itmo544SKelb --instances ${instanceARR[@]}
aws elb configure-health-check --load-balancer-name itmo544SKelb --health-check Target=HTTP:80/index.html,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3

#echo -e "\n waiting for an extra 3 minutes before opening elb in browser"
#for i in {0..180}; do echo -ne '.'; sleep 1;done
#echo "\n"

aws autoscaling create-launch-configuration --launch-configuration-name itmo544launchconfig --image-id ami-d05e75b8 --key-name ITMO544-Fall2015-VirtualBox --security-groups sg-18b4bc7f --instance-type t2.micro --user-data file:///home/controller/ITMO544-Fall-EnvSetup-MP1/install-env.sh --iam-instance-profile PHPDeveloperRole

aws autoscaling create-auto-scaling-group --auto-scaling-group-name itmo544extendedautoscalinggroup2 --launch-configuration-name itmo544launchconfig --load-balancer-names itmo544SKelb  --health-check-type ELB --min-size 1 --max-size 3 --desired-capacity 2 --default-cooldown 600 --health-check-grace-period 120 --vpc-zone-identifier subnet-5e540975 

aws autoscaling put-scaling-policy --auto-scaling-group-name itmo544extendedautoscalinggroup2  --policy-name scalingpolicytest --scaling-adjustment 1 --adjustment-type ExactCapacity

aws cloudwatch put-metric-alarm --alarm-name AddCapacity --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 60 --threshold 30 --comparison-operator GreaterThanOrEqualToThreshold --dimensions "Name=AutoScalingGroup,Value=itmo544extendedautoscalinggroup2" --evaluation-periods 1 --alarm-actions arn:aws:autoscaling:us-east-1:431676597021:scalingPolicy:b01ac362-a460-45fa-b797-813c303becfa:autoScalingGroupName/itmo544extendedautoscalinggroup2:policyName/scalingpolicytest

aws rds create-db-subnet-group --db-subnet-group-name subnetgrp1 --subnet-ids subnet-5e540975 subnet-2e250a77 --db-subnet-group-description createdoncomdpmt

aws rds create-db-instance --db-name MiniProjectData --db-instance-identifier MP1 --db-instance-class db.t2.micro --engine MySql --allocated-storage 20 --master-username snehamp1db --master-user-password snehamp1db --db-subnet-group-name default-vpc-fb2ae59f

