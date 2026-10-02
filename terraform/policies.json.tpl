{
    "tag_policy": {
        "tags": {
            "Project": {
                "tag_key": {
                    "@@assign": "Project"
                }
            },
            "Environment": {
                "tag_key": {
                    "@@assign": "Environment"
                },
                "tag_value": {
                    "@@assign": [
                        "prod",
                        "test",
                        "shared"
                    ]
                }
            },
            "OS_version": {
                "tag_key": {
                    "@@assign": "OS_version"
                },
                "tag_value": {
                    "@@assign": ${allowed_ec2_os}
                },
                "enforced_for": {
                    "@@assign": [
                        "ec2:instance",
                        "ec2:image"
                    ]
                }
            }
        }
    }
}
