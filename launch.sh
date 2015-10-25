#!/bin/bash

./cleanup.sh

#declare a variable

declare -a instanceARR

mapfile -t instanceARR < <(aws ec2 run-instances --image-id ami-d05e75b8 --count 2 --instance-type t2.micro --key-name ITMO544-Fall2015-VirtualBox --security-group-id sg-18b4bc7f --subnet-id subnet-5e540975 --associate-public-ip-address --iam-instance-profile Name=PHPDeveloperRole --user-data file://ITMO544-Fall-EnvSetup/install-env.sh --output table | grep InstanceId | sed "s/|//g" | tr -d ' ' | sed "s/InstanceId//g")

#aws ec2 run-instances --image-id ami-d05e75b8 --count 2 --instance-type t2.micro --key-name ITMO544-Fall2015-VirtualBox --security-group-id sg-18b4bc7f --subnet-id subnet-5e540975 --associate-public-ip-address --user-data file://install-webserver.sh --debug
echo ${instanceARR[@]}

aws ec2 wait intsance-running --instance-ids ${instanceARR[@]}
echo "instances are running"

ELBURL= ('aws elb create-load-balancer --load-balancer-name itmo544SKelb --listeners Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80 --security-groups sg-18b4bc7f --subnets subnet-5e540975 --output=text');
echo $ELBURL
echo -e "\n Finished launching ELB and sleeping 25 seconds"
for i in {0..25}; do echo -ne '.'; sleep 1;done
echo "\n"

aws elb register-instances-with-load-balancer --load-balancer-name itmo544SKelb --instances ${instanceARR[@]}
aws elb configure-health-check --load-balancer-name itmo544SKelb --health-check Target=HTTP:80/index.html,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3

echo -e "\n waiting for an extra 3 minutes before opening elb in browser"
for i in {0..180}; do echo -ne '.'; sleep 1;done
echo "\n"

aws autoscaling create-launch-configuration --launch-configuration-name itmo544launchconfig --image-id ami-d05e75b8 --key-name ITMO544-Fall2015-VirtualBox --security-groups sg-18b4bc7f --instance-type t2.micro --user-data file://ITMO544-Fall-EnvSetup/install-env.sh --iam-instance-profile PHPDeveloperRole

aws autoscaling create-auto-scaling-group --auto-scaling-group-name itmo544extendedautoscalinggroup2 --launch-configuration-name itmo544launchconfig --load-balancer-names itmo544SKelb  --health-check-type ELB --min-size 1 --max-size 3 --desired-capacity 2 --default-cooldown 600 --health-check-grace-period 120 --vpc-zone-identifier subnet-5e540975 