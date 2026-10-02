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
                        "shared",
                        "management"
                    ]
                }
            }
        }
    }
}
