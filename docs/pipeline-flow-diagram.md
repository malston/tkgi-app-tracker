# TKGI Application Tracker - Pipeline Flow Diagram

## Single Pipeline with Multiple Jobs

Each foundation deploys **one Concourse pipeline** (`pipelines/single-foundation-report.yml`) containing **two jobs** and a **manual-trigger resource** for on-demand execution.

## Complete Pipeline Flow

```sh
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                            TKGI APPLICATION TRACKER PIPELINE (Single Pipeline)                                  │
│                          Foundation-Specific Deployment with Multiple Jobs                                      │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

                                              TRIGGERS
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                        │
│ │  Weekly Timer   │    │   Git Changes   │    │ Manual Trigger  │    │ Config Changes  │                        │
│ │                 │    │                 │    │                 │    │                 │                        │
│ │ Mon 6:00 AM ET  │    │ Source Code     │    │ fly trigger-job │    │ Foundation      │                        │
│ │ Automatic       │    │ Auto-Test       │    │ On-Demand       │    │ Parameters      │                        │
│ └─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘                        │
└───────────┼──────────────────────┼──────────────────────┼──────────────────────┼────────────────────────────────┘
            │                      │                      │                      │
            │                      │                      │                      │
            ▼                      ▼                      ▼                      ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                           RESOURCE INPUTS                                                       │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ ┌───────────────────┐  ┌──────────────────┐  ┌───────────────────┐  ┌──────────────────┐                        │
│ │ s3-container-image│  │ tkgi-app-tracker │  │    config-repo    │  │   weekly-timer   │                        │
│ │                   │  │      -repo       │  │                   │  │                  │                        │
│ │ • cflinux base    │  │ • Source code    │  │ • Foundation      │  │ • Schedule       │                        │
│ │ • om CLI          │  │ • Scripts        │  │   configs         │  │ • Interval       │                        │
│ │ • tkgi CLI        │  │ • Task files     │  │ • Environment     │  │ • Timezone       │                        │
│ │ • kubectl         │  │ • Documentation  │  │   specific        │  │                  │                        │
│ │ • Python 3.9+     │  │ • Tests          │  │                   │  │                  │                        │
│ └───────────┬───────┘  └──────────┬───────┘  └──────────┬────────┘  └─────────┬────────┘                        │
└─────────────┼─────────────────────┼─────────────────────┼─────────────────────┼─────────────────────────────────┘
              │                     │                     │                     │
              └─────────────────────┼─────────────────────┼─────────────────────┘
                                    │                     │
                                    ▼                     ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                        JOB: collect-and-report                                                  │
│                                      (Primary weekly execution job)                                             │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                 │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                                     TASK: collect-data                                                    │  │
│  │                                    Duration: 5-10 minutes                                                 │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │                                                                                                           │  │
│  │ ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐                             │  │
│  │ │   Environment       │    │    Authentication   │    │   TKGI Discovery    │                             │  │
│  │ │   Setup             │───▶│                     │───▶│                     │                             │  │
│  │ │                     │    │ 1. om CLI login     │    │ 1. tkgi clusters    │                             │  │
│  │ │ • Foundation vars   │    │ 2. Get admin pw     │    │ 2. Cluster list     │                             │  │
│  │ │ • API endpoints     │    │ 3. tkgi login       │    │ 3. Get credentials  │                             │  │
│  │ │ • Credentials       │    │ 4. Set kubeconfig   │    │ 4. Context setup    │                             │  │
│  │ └─────────────────────┘    └─────────────────────┘    └─────────┬───────────┘                             │  │
│  │                                                                 │                                         │  │
│  │ ┌───────────────────────────────────────────────────────────────┴─────────────────────────────────────┐   │  │
│  │ │                                  Per-Cluster Data Collection                                        │   │  │
│  │ │                                                                                                     │   │  │
│  │ │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                 │   │  │
│  │ │  │   Namespaces    │  │      Pods       │  │    Services     │  │   Deployments   │                 │   │  │
│  │ │  │                 │  │                 │  │                 │  │                 │                 │   │  │
│  │ │  │ kubectl get ns  │  │ kubectl get     │  │ kubectl get     │  │ kubectl get     │                 │   │  │
│  │ │  │ --output=json   │  │ pods -A         │  │ svc -A          │  │ deploy -A       │                 │   │  │
│  │ │  │                 │  │ --output=json   │  │ --output=json   │  │ --output=json   │                 │   │  │
│  │ │  └─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘                 │   │  │
│  │ │                                            │                                                        │   │  │
│  │ │  ┌─────────────────────────────────────────▼──────────────────────────────────────┐                 │   │  │
│  │ │  │                          JSON Data Structuring                                 │                 │   │  │
│  │ │  │                                                                                │                 │   │  │
│  │ │  │ • Extract namespace metadata (labels, annotations, creation time)              │                 │   │  │
│  │ │  │ • Count resources per namespace (pods, services, deployments)                  │                 │   │  │
│  │ │  │ • Classify system vs application namespaces                                    │                 │   │  │
│  │ │  │ • Extract AppID from labels/annotations                                        │                 │   │  │
│  │ │  │ • Determine activity status (pod creation timestamps)                          │                 │   │  │
│  │ │  │ • Associate with foundation/datacenter/environment                             │                 │   │  │
│  │ │  └────────────────────────────────────────────────────────────────────────────────┘                 │   │  │
│  │ └─────────────────────────────────────────────────────────────────────────────────────────────────────┘   │  │
│  │                                                                                                           │  │
│  │ Output: collected-data/data/all_clusters_TIMESTAMP.json                                                   │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                            │                                                    │
│                                                            ▼                                                    │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                                    TASK: aggregate-data                                                   │  │
│  │                                   Duration: 2-5 minutes                                                   │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │                                                                                                           │  │
│  │ ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐                             │  │
│  │ │   Data Loading      │    │   Classification    │    │   Scoring Engine    │                             │  │
│  │ │                     │───▶│                     │───▶│                     │                             │  │
│  │ │ • Load JSON files   │    │ • System namespace  │    │ • Migration ready   │                             │  │
│  │ │ • Validate schema   │    │   detection         │    │   scoring (0-100)   │                             │  │
│  │ │ • Merge datasets    │    │ • Application       │    │ • Risk assessment   │                             │  │
│  │ │ • Remove duplicates │    │   identification    │    │ • Priority ranking  │                             │  │
│  │ └─────────────────────┘    └─────────────────────┘    └─────────┬───────────┘                             │  │
│  │                                                                 │                                         │  │
│  │ ┌───────────────────────────────────────────────────────────────┴───────────────────────────────────────┐ │  │
│  │ │                                    Analytics Processing                                               │ │  │
│  │ │                                                                                                       │ │  │
│  │ │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                   │ │  │
│  │ │  │   Historical    │  │   Trend         │  │   Foundation    │  │   Environment   │                   │ │  │
│  │ │  │   Comparison    │  │   Analysis      │  │   Statistics    │  │   Classification│                   │ │  │
│  │ │  │                 │  │                 │  │                 │  │                 │                   │ │  │
│  │ │  │ • Previous week │  │ • Growth rates  │  │ • Cluster usage │  │ • Prod vs NonP  │                   │ │  │
│  │ │  │ • Delta calc    │  │ • Migration     │  │ • App density   │  │ • Risk levels   │                   │ │  │
│  │ │  │ • Change detect │  │   velocity      │  │ • Utilization   │  │ • Compliance    │                   │ │  │
│  │ │  └─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘                   │ │  │
│  │ └───────────────────────────────────────────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                                                           │  │
│  │ Output: aggregated-data/reports/applications_TIMESTAMP.json                                               │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                            │                                                    │
│                                                            ▼                                                    │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                                   TASK: generate-reports                                                  │  │
│  │                                   Duration: 1-3 minutes                                                   │  │
│  ├───────────────────────────────────────────────────────────────────────────────────────────────────────────┤  │
│  │                                                                                                           │  │
│  │ ┌───────────────────────────────────────────────────────────────────────────────────────────────────────┐ │  │
│  │ │                                     Report Generation Matrix                                          │ │  │
│  │ │                                                                                                       │ │  │
│  │ │  ┌──────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                  │ │  │
│  │ │  │   Application    │  │   Executive     │  │   Migration     │  │   Cluster       │                  │ │  │
│  │ │  │     Report       │  │    Summary      │  │    Priority     │  │   Utilization   │                  │ │  │
│  │ │  │                  │  │                 │  │                 │  │                 │                  │ │  │
│  │ │  │ • Full inventory │  │ • High-level    │  │ • Ranked list   │  │ • Resource      │                  │ │  │
│  │ │  │ • Readiness      │  │   metrics       │  │ • Risk assess   │  │   distribution  │                  │ │  │
│  │ │  │   scores         │  │ • Foundation    │  │ • Actions req   │  │ • App density   │                  │ │  │
│  │ │  │ • Metadata       │  │   summaries     │  │ • Timeline est  │  │ • Comparisons   │                  │ │  │
│  │ │  │ • Recommendations│  │ • Trends        │  │ • Dependencies  │  │                 │                  │ │  │
│  │ │  └──────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘                  │ │  │
│  │ │                                            │                                                          │ │  │
│  │ │  ┌─────────────────────────────────────────▼────────────────────────────────────────┐                 │ │  │
│  │ │  │                              Format Generation                                   │                 │ │  │
│  │ │  │                                                                                  │                 │ │  │
│  │ │  │ ┌─────────────────┐                         ┌─────────────────┐                  │                 │ │  │
│  │ │  │ │   CSV Format    │                         │   JSON Format   │                  │                 │ │  │
│  │ │  │ │                 │                         │                 │                  │                 │ │  │
│  │ │  │ │ • Excel ready   │                         │ • API ready     │                  │                 │ │  │
│  │ │  │ │ • Pivot tables  │                         │ • Automation    │                  │                 │ │  │
│  │ │  │ │ • Management    │                         │ • Integration   │                  │                 │ │  │
│  │ │  │ │   consumption   │                         │ • Processing    │                  │                 │ │  │
│  │ │  │ └─────────────────┘                         └─────────────────┘                  │                 │ │  │
│  │ │  └──────────────────────────────────────────────────────────────────────────────────┘                 │ │  │
│  │ └───────────────────────────────────────────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                                                           │  │
│  │ Output: generated-reports/reports/*.csv, *.json                                                           │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                            │                                                    │
│                                                            ▼                                                    │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                                   TASK: package-reports                                                    │ │
│  │                                   Duration: <1 minute                                                      │ │
│  ├────────────────────────────────────────────────────────────────────────────────────────────────────────────┤ │
│  │                                                                                                            │ │
│  │ ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐                              │ │
│  │ │   Timestamping      │    │    Compression      │    │      Naming         │                              │ │
│  │ │                     │───▶│                     │───▶│                     │                              │ │
│  │ │ • Generate YYYYMMDD │    │ • tar.gz format     │    │ • Foundation prefix │                              │ │
│  │ │   _HHMMSS stamp     │    │ • Optimize size     │    │ • Environment tag   │                              │ │
│  │ │ • UTC timezone      │    │ • Preserve struct   │    │ • Version control   │                              │ │
│  │ │ • Sortable format   │    │ • Fast extraction   │    │ • S3 path ready     │                              │ │
│  │ └─────────────────────┘    └─────────────────────┘    └─────────────────────┘                              │ │
│  │                                                                                                            │ │
│  │ Output: packaged-reports/weekly-report-FOUNDATION-TIMESTAMP.tar.gz                                         │ │
│  └────────────────────────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                            │                                                    │
│                                                            ▼                                                    │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                                      S3 UPLOAD                                                             │ │
│  │                                    Duration: <1 minute                                                     │ │
│  ├────────────────────────────────────────────────────────────────────────────────────────────────────────────┤ │
│  │                                                                                                            │ │
│  │ ┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐ │ │
│  │ │                                    S3 Storage Strategy                                                 │ │ │
│  │ │                                                                                                        │ │ │
│  │ │  Bucket: tkgi-app-tracker-reports-{environment}                                                        │ │ │
│  │ │  Path: reports/{foundation}/weekly-report-{foundation}-{timestamp}.tar.gz                              │ │ │
│  │ │                                                                                                        │ │ │
│  │ │  Features:                                                                                             │ │ │
│  │ │  • Versioned storage (12-month retention)                                                              │ │ │
│  │ │  • Environment isolation (lab/nonprod/prod)                                                            │ │ │
│  │ │  • Foundation-specific organization                                                                    │ │ │
│  │ │  • Automated lifecycle management                                                                      │ │ │
│  │ │  • IAM-based access control                                                                            │ │ │
│  │ └────────────────────────────────────────────────────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                            │                                                    │
│                                                            ▼                                                    │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                                    TASK: notify-success                                                    │ │
│  │                                    Duration: <1 minute                                                     │ │
│  ├────────────────────────────────────────────────────────────────────────────────────────────────────────────┤ │
│  │                                                                                                            │ │
│  │ ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐                              │ │
│  │ │   Message Format    │    │   Teams Webhook     │    │   Stakeholder       │                              │ │
│  │ │                     │───▶│                     │───▶│   Notification      │                              │ │
│  │ │ • Success status    │    │ • HTTP POST         │    │ • Management team   │                              │ │
│  │ │ • Foundation ID     │    │ • JSON payload      │    │ • Platform eng      │                              │ │
│  │ │ • S3 location       │    │ • Retry logic       │    │ • Application teams │                              │ │
│  │ │ • Report summary    │    │ • Error handling    │    │ • Operations staff  │                              │ │
│  │ └─────────────────────┘    └─────────────────────┘    └─────────────────────┘                              │ │
│  └────────────────────────────────────────────────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                          ERROR HANDLING                                                         │
│                                                                                                                 │
│  Each Task Has on_failure:                                                                                      │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                                    TASK: notify-failure                                                    │ │
│  │                                                                                                            │ │
│  │ ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐                              │ │
│  │ │   Error Context     │    │   Alert Message     │    │   Incident          │                              │ │
│  │ │                     │───▶│                     │───▶│   Response          │                              │ │
│  │ │ • Task name         │    │ • Failure reason    │    │ • Log analysis      │                              │ │
│  │ │ • Foundation ID     │    │ • Troubleshooting   │    │ • Manual execution  │                              │ │
│  │ │ • Error details     │    │   guidance          │    │ • Issue tracking    │                              │ │
│  │ │ • Timestamp         │    │ • Escalation path   │    │ • Resolution        │                              │ │
│  │ └─────────────────────┘    └─────────────────────┘    └─────────────────────┘                              │ │
│  └────────────────────────────────────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

                            MANUAL TRIGGER PATTERN
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ The manual-trigger resource (70000h interval) enables on-demand execution:                                      │
│                                                                                                                 │
│ • Weekly Timer: Automatically triggers collect-and-report job                                                   │
│ • Manual Execution: fly -t {foundation} trigger-job -j tkgi-app-tracker-{foundation}/collect-and-report         │
│ • Manual-trigger Resource: Acts as completion marker, put at end of collect-and-report                          │
│                                                                                                                 │
│ This pattern eliminates job duplication while supporting both automatic and manual execution                    │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                      JOB: test-pipeline                                                         │
│                                   (Continuous integration job)                                                  │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Trigger: Git repository changes (automatic)                                                                     │
│ Purpose: Code quality validation, regression testing                                                            │
│                                                                                                                 │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                                    TASK: run-unit-tests                                                    │ │
│  │                                   Duration: 2-5 minutes                                                    │ │
│  ├────────────────────────────────────────────────────────────────────────────────────────────────────────────┤ │
│  │                                                                                                            │ │
│  │ ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐                              │ │
│  │ │   BATS Testing      │    │   Mock Data Tests   │    │   Logic Validation  │                              │ │
│  │ │                     │───▶│                     │───▶│                     │                              │ │
│  │ │ • Shell script      │    │ • Sample JSON       │    │ • Function tests    │                              │ │
│  │ │   testing           │    │ • Expected outputs  │    │ • Edge cases        │                              │ │
│  │ │ • Integration tests │    │ • Error scenarios   │    │ • Data validation   │                              │ │
│  │ │ • API mocking       │    │ • Boundary testing  │    │ • Result checking   │                              │ │
│  │ └─────────────────────┘    └─────────────────────┘    └─────────────────────┘                              │ │
│  └────────────────────────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                            │                                                    │
│                                                            ▼                                                    │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                                  TASK: validate-scripts                                                    │ │
│  │                                  Duration: 1-2 minutes                                                     │ │
│  ├────────────────────────────────────────────────────────────────────────────────────────────────────────────┤ │
│  │                                                                                                            │ │
│  │ ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐                              │ │
│  │ │   Syntax Checking   │    │   Style Validation  │    │   Security Scanning │                              │ │
│  │ │                     │───▶│                     │───▶│                     │                              │ │
│  │ │ • Bash syntax       │    │ • Shellcheck lint   │    │ • Secret detection  │                              │ │
│  │ │ • Python syntax     │    │ • Code standards    │    │ • Vulnerability     │                              │ │
│  │ │ • YAML validation   │    │ • Best practices    │    │   scanning          │                              │ │
│  │ │ • JSON validation   │    │ • Error patterns    │    │ • Permission checks │                              │ │
│  │ └─────────────────────┘    └─────────────────────┘    └─────────────────────┘                              │ │
│  └────────────────────────────────────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                        DEPLOYMENT ARCHITECTURE                                                  │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                 │
│  ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐       │
│  │      DC01 Lab       │    │    DC02 NonProd     │    │    DC03 Prod        │    │    DC04 Prod        │       │
│  │                     │    │                     │    │                     │    │                     │       │
│  │ dc01-k8s-n-01       │    │ dc02-k8s-n-01       │    │ dc03-k8s-p-01       │    │ dc04-k8s-p-01       │       │
│  │ dc01-k8s-n-02       │    │ dc02-k8s-n-02       │    │ dc03-k8s-p-02       │    │ dc04-k8s-p-02       │       │
│  │ dc01-k8s-n-03       │    │ dc02-k8s-n-03       │    │ dc03-k8s-p-03       │    │ dc04-k8s-p-03       │       │
│  │ ...                 │    │ ...                 │    │ ...                 │    │ ...                 │       │
│  │                     │    │                     │    │                     │    │                     │       │
│  │ One Pipeline per    │    │ One Pipeline per    │    │ One Pipeline per    │    │ One Pipeline per    │       │
│  │ Foundation          │    │ Foundation          │    │ Foundation          │    │ Foundation          │       │
│  │ (2 jobs each)       │    │ (2 jobs each)       │    │ (2 jobs each)       │    │ (2 jobs each)       │       │
│  │                     │    │                     │    │                     │    │                     │       │
│  │ Shared Parameters   │    │ Shared Parameters   │    │ Shared Parameters   │    │ Shared Parameters   │       │
│  │ dc01-k8s-tkgi-      │    │ dc02-k8s-tkgi-      │    │ dc03-k8s-tkgi-      │    │ dc04-k8s-tkgi-      │       │
│  │ app-tracker.yml     │    │ app-tracker.yml     │    │ app-tracker.yml     │    │ app-tracker.yml     │       │
│  └─────────────────────┘    └─────────────────────┘    └─────────────────────┘    └─────────────────────┘       │
│                                                                                                                 │
│  Each Foundation → One Pipeline (2 Jobs) → Foundation-Specific Reports → Datacenter-Aggregated Analysis         │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

                                              LEGEND
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ ┌─────────────┐  = Process/Task          ───▶ = Data Flow           ┌──────────────┐ = Storage/Output           │
│ │   Process   │                                                     │   Storage    │                            │
│ └─────────────┘                                                     └──────────────┘                            │
│                                                                                                                 │
│ ▼ = Sequential Flow              ═══▶ = Parallel Flow              ((parameter)) = Concourse Parameter          │
│                                                                                                                 │
│ Duration estimates based on:                                                                                    │
│ • 10-50 clusters per foundation                                                                                 │
│ • 100-1000 namespaces per cluster                                                                               │
│ • Standard network connectivity                                                                                 │
│ • Normal API response times                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```
