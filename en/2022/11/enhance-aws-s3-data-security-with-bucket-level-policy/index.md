# Enhance AWS S3 Data Security with Bucket Level Policy


After restricted the source of S3 Bucket access requests through Bucket Level Policy, the data in AWS S3 Bucket can still be secured even if AKSK is compromised.

<!--more-->

## Background

Due to weak security awareness, many people prefer to access resources through AKSK (Access Key and Secret Key). AKSK contains only two strings and the user permissions can be obtained via command line tools or API codes. 

Take AWS as an example, a simple `aws s3 sync` command can drag away all the data stored in S3 Bucket. After restricted the source of S3 Bucket access requests through Bucket Level Policy, the data in AWS S3 Bucket can still be secured even if AKSK is compromised.

One prerequisite is that the compromised AKSK should not have administrator privileges or full privileges of services such as IAM, EC2, Lambda, etc. Otherwise, it may bypass the Bucket Level Policy restrictions or modify the Bucket Level Policy through those services. For such cases, restrictions could be imposed on various services from the organization account level by SCP.

## Policy example

The following Bucket Level Policy uses the `Deny` by default, only allows the following types of requests.

1. When requests come directly from AWS services.
2. When requests come from the specified VPC IDs.
3. When requests come from the specified Roles.
4. When requests come from the specified IPs.

```json
{
    "Version": "2012-10-17",
    "Id": "RestrictVPCsAndARNsAndSourceIPs",
    "Statement": [
        {
            "Sid": "VPCsAndARNsAndSourceIPs",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::bucket-name",
                "arn:aws:s3:::bucket-name/*"
            ],
            "Condition": {
                "Bool": {
                    "aws:ViaAWSService": "false"
                },            
                "StringNotEqualsIfExists": {
                    "aws:SourceVpc": [
                        "vpc-857abc857abc875aa",
                        "vpc-857cba857cba875bb"
                    ]
                },
                "ArnNotLikeIfExists": {
                    "aws:PrincipalArn": [
                        "arn:aws:iam::857857857857:role/role-name",
                        "arn:aws:iam::361361361361:role/role-name",
                        "arn:aws:iam::857857857857:role/role*",
                        "arn:aws:iam::361361361361:role/role*"
                    ]
                },
                "NotIpAddressIfExists": {
                    "aws:SourceIp": [
                        "8.5.7.11/32",
                        "8.5.7.22/32"
                    ]
                }
            }
        }
    ]
}
```

## Better solution

Here are some strong protection mechanisms for the data in Amazon S3, including least privilege access, encryption of data at rest, restricted sources, logging, monitoring, and configuration checks.

1. Restrict the sources of requests at the organization level for S3 and other AWS services 
2. Use bucket policies to verify all access granted is restricted and specific
3. Enable S3 protection in GuardDuty to detect suspicious activities
4. Use Macie to scan for sensitive data outside of designated areas
5. Use KMS to encrypt data in S3
6. Protect data in S3 from accidental deletion using S3 Versioning and S3 Object Lock
7. Enable logging for S3 using CloudTrail and S3 server access logging
8. Monitor S3 using Security Hub and CloudWatch Logs
9. Use Cross-region replicatio to backup data in S3

## References

https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies.html  
https://aws.amazon.com/cn/blogs/security/top-10-security-best-practices-for-securing-data-in-amazon-s3/

