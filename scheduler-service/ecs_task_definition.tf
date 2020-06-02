resource "aws_ecs_task_definition" "default" {
  family       = "${local.prefix}"
  network_mode = "awsvpc"

  requires_compatibilities = [
    "EC2",
  ]

  cpu                = "${var.fargate_cpu}"
  memory             = "${var.fargate_memory}"
  task_role_arn      = "${aws_iam_role.role.arn}"
  execution_role_arn = "${aws_iam_role.role.arn}"

  container_definitions = <<DEFINITION
[

  {
    "cpu": ${var.fargate_cpu - 100},
    "memory":${var.fargate_memory - 100},
    "image": "${var.ecr_repository_url}:${var.common_tags["env"]}",
    "name": "${var.container_name}",
    "networkMode": "awsvpc",
    "command": [
      "/bin/sh",
      "-c",
      "airflow scheduler"
    ],
    "environment": [
      {
        "name": "AIRFLOW__CORE__SQL_ALCHEMY_CONN",
        "value": "${var.secrets["air_core_sql_conn"]}"
      },
      {
        "name": "AIRFLOW__CORE__EXECUTOR",
        "value" : "CeleryExecutor"
      },
      {
        "name": "AIRFLOW__CORE__LOAD_EXAMPLES",
        "value": "false"
      },
      {
        "name": "AIRFLOW__CELERY__BROKER_URL",
        "value": "${var.secrets["broker_url"]}"
      },
      {
        "name": "AIRFLOW__CELERY__RESULT_BACKEND",
        "value": "db+${var.secrets["air_core_sql_conn"]}"
      },
      {
        "name": "C_FORCE_ROOT",
        "value": "true"
      },
      {
        "name": "AIRFLOW__CORE__REMOTE_LOGGING",
        "value": "true"
      },
      {
        "name": "AIRFLOW__CORE__REMOTE_BASE_LOG_FOLDER",
        "value": "s3://${var.s3_logging["bucket"]}/airflow"
      },
      {
        "name": "S3_DATA_LAKE_BUCKET",
        "value": "${var.s3_data_lake["bucket"]}"
      },
      {
        "name": "AIRFLOW_CONN_CRG_PRD",
        "value": "${var.secrets["crg_prd"]}"
      },
      {
        "name": "AIRFLOW_CONN_CRG_DWH",
        "value": "${var.secrets["dwh_db"]}"
      },
      {
        "name": "AIRFLOW__CORE__FERNET_KEY",
        "value": "${var.secrets["fernet_key"]}"
      },
      {
        "name": "AIRFLOW__SCHEDULER__STATSD_ON",
        "value": "true"
      },
      {
        "name": "AIRFLOW__SCHEDULER__STATSD_HOST",
        "value": "localhost"
      },
      {
        "name": "AIRFLOW__SCHEDULER__STATSD_PORT",
        "value": "${var.cwagent_port}"
      },
      {
        "name": "AIRFLOW__SCHEDULER__STATSD_PREFIX",
        "value": "airflow"
      },
      {
        "name": "AIRFLOW__SCHEDULER__STATSD_ALLOW_LIST",
        "value": "scheduler,executor,dagrun"

      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.ecs.name}",
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "${var.prefix}-"
      }
    },
    "portMappings": [
      {
        "containerPort": ${var.app_port},
        "hostPort": ${var.app_port}
      }
    ]
  },
  {
    "name": "cloudwatch-agent",
    "image": "amazon/cloudwatch-agent:latest",
    "cpu": 100,
    "memory":256,
    "secrets": [
                {
                    "name": "CW_CONFIG_CONTENT",
                    "valueFrom":  "${data.aws_secretsmanager_secret.ecs-cwagent.arn}"
                }
            ],
    "logConfiguration": {
    "logDriver": "awslogs",
    "options": {
                    "awslogs-create-group": "True",
                    "awslogs-group": "${aws_cloudwatch_log_group.ecs.name}",
                    "awslogs-region": "${data.aws_region.current.name}",
                    "awslogs-stream-prefix": "${var.prefix}-cwagent"
                }
    },
    "portMappings": [
      {
        "containerPort": ${var.cwagent_port},
        "hostPort": ${var.cwagent_port}
      }
    ]

  }

]
DEFINITION
}
