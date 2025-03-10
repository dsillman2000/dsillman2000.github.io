---
layout: post
author: David Sillman
title: "TF-GCP I: Provisioning GCP resources with Terraform"
---

I was recently challenged at work to come up with a long-term personal development goal for the year. As our team is moving increasingly towards cloud computing, I know that eventually I will hit a ceiling if I don't know something about Terraform. I've heard Terraform mentioned in passing and taken some time to learn the most basic information about how it works and what projects which use it generally look like.

At work, our team is using Amazon (AWS) as the cloud platform for all of our services. This is probably the most economical choice, but I wanted to try something new and learn about some of the differences between AWS and Google's cloud platform, GCP (Google Cloud Platform).

<img class="centered-image dark-inverted" alt="GCP Terraform" src="/assets/images/gcp_terraform.jpeg"/>

One of the most basic things you can do in the cloud is set up a publicly-accessible static website by using cloud storage. Basically, you're just uploading static files to a cloud server and configuring it to serve those files to the public using a managed URL. This is a great way to host all sorts of things from blogs, resumes or project documentation.

## How they tell you to do it, vs. how you should do it

If you follow any tutorials on GCP (or any other cloud platform), they'll explain how to do this using the Google Cloud Console (or AWS cloud console for AWS), which is just a UI interface for managing cloud resources. This is great for learning how things work, but it's not a great way to manage your infrastructure in the long term. Ideally, your infrastructure specs would be layed out in code and tracked in version control, so that you can see how your infrastructure has changed over time and roll back changes if necessary.

This is where **Terraform** comes in. Terraform is a DSL (domain-specific language) for defining the cloud resources managed by a project. The cloud resources could straddle many different cloud providers, but in this case we're just using GCP. Learning Terraform is generally a good way to learn about how different cloud resources can interact with one another to build a larger, multi-component system.

\\
Thankfully, a static site doesn't require more than one component - our provisioned cloud storage. So this project shouldn't be too complicated...

...right?

## Prerequisites

\\
There are a few things that took me a little bit to realize I needed installed as I was getting started:

1. **Terraform CLI**: AKA the `terraform` CLI. If you're using Mac OSX, you can install this with Homebrew. But installation for all other platforms is pretty straightforward. You can find the installation instructions on [their website](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).

    \\
    If you successfully managed to install Terraform, you should be able to run the following     command in your terminal:
    
    ```bash
    terraform --version
    ```
   
2. **Google Cloud CLI**: AKA the `gcloud` CLI. On Mac OSX, you're required to download the corresponding `.dmg` file from the [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) website and follow the given instructions (basically just run a bash script).

    \\
    If you successfully managed to install the Google Cloud CLI, you should be able to run     the following command in your terminal:
    
    ```bash
    gcloud --version
    ```

Once these two are installed, you're more or less ready to get started. There are just a few other things which we'd want to configure about our Google Cloud setup before we start provisioning resources.

## Setting up Google Cloud

\\
Once `gcloud` is installed, you'll want to authenticate your Google account with the CLI. This is done by running the following command:

```bash
gcloud auth login
```

This will take you through an interactive set of web pages to authenticate your Google account with the CLI. Once you've authenticated, you'll be able to run commands against your Google Cloud account.

---

In Google Cloud, there's a hierarchical structure to how resources are organized. At the top level, you (optionally) have an *Organization*, which may contain multiple *Projects*. Each *Project* independently manages its permissions and resources. By default, consumer GCP accounts do not have an Organization configured, so you'll create projects in the root of your account (no Organization containing them).

\\
To get started, we'll create a *Project* for the static site we want to host on GCP. I'll cal my project `davids-static-site`.

```bash
gcloud projects create davids-static-site
```

\\
After creating the project, wait about 30 - 60 seconds for the project to fully materialize in Google Cloud. You can check the status of your project by running the following command:

```bash
gcloud projects describe davids-static-site
```

\\
Once that project is created, meaning its status is "ACTIVE" in the output of the `describe` command, you can set it as the default project for the `gcloud` CLI:

```bash
gcloud config set project davids-static-site
```

The last step in ensuring our account and project are properly set up is to enable billing for the project. This is required to provision any resources in GCP. You can enable billing for the project by running the following command:

```bash
# Check your available billing account IDs
gcloud billing accounts list
# Set one to use for the new project
gcloud billing projects link davids-static-site --billing-account=<billing-account-id>
```

\\
Now that we have a project and billing set up for our account, we can start provisioning resources in GCP. We're finally ready to start tinkering with Terraform!

## Setting up our Terraform project

\\
Alright, first things first. I'm going to create a fresh directory for the project where I like to organize these things, which is in my `$HOME/terraform-projects` directory. I'll call this project `gcp-static-site`.

```bash
mkdir -p $HOME/terraform-projects/gcp-static-site
cd $HOME/terraform-projects/gcp-static-site
```

> **Note**: The way that I'm choosing to split my code across files is more or less arbitrary. I'm following some conventions I've learned from co-workers and from reading the Terraform documentation. I'm sure there are many ways to organize your Terraform code, but this is just one way that I think is pretty clean.

The first thing I do to set up my project is to create a `versions.tf` file. The only thing I'll put in this file is the **`terraform` block** for our project. This block specifies the version of Terraform that we're using, and it's a good idea to specify this in every Terraform project you create. I also use it to specify the required version of the Google Cloud provider plugin.

```hcl
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.24.0"
    }
  }
}
```

\\
Now that we have this config block in our directory, we can just run `terraform init` to instruct Terraform to read it and download the required provider plugin for Google Cloud.

<details>

<summary><code>terraform init</code> output</summary>

<div markdown=1>

```bash
$ terraform init
  Initializing the backend...
  Initializing provider plugins...
  - Finding hashicorp/google versions matching "6.24.0"...
  - Installing hashicorp/google v6.24.0...
  - Installed hashicorp/google v6.24.0 (signed by HashiCorp)
  Terraform has created a lock file .terraform.lock.hcl to record the 
  provider selections it made above. Include this file in your version control 
  repository so that Terraform can guarantee to make the same selections by default 
  when you run "terraform init" in the future.
  
  Terraform has been successfully initialized!
  
  You may now begin working with Terraform. Try running "terraform plan" to 
  see any changes that are required for your infrastructure. All Terraform 
  commands should now work.
  
  If you ever set or change modules or backend configuration for Terraform,
  rerun this command to reinitialize your working directory. If you forget, 
  other commands will detect it and remind you to do so if necessary.
```

</div>

</details>

This should have done a few things. First, you should see a `.terraform` directory in the project, which basically saves the downloaded provider plugins and other state information. Second, you should see a `.terraform.lock.hcl` file, which is a lock file that specifies the exact versions of the provider plugins that were downloaded. I think of this as analogous to `poetry.lock`, or event `requirements.txt` in Python projects.

## Let's provision a GCS bucket

Ok, great. So our Terraform project is initialized. How can we get it to provision a Google Cloud Storage (GCS) bucket for us?

\\
A GCS bucket is essentially just a shared storage location, like a mini file system which can be accessed via API requests, much like Amazon's equivalent Simple Storage Service (S3).

Since our project is essentially just using this cloud storage to host some static site pages, we'll obviously want the ownership of this storage bucket to fall within our project. So, let's create a dedicated Terraform file for provisioning the GCS bucket, called `bucket.tf`, with a **`resource` block** defined in it:

```hcl
resource "google_storage_bucket" "static_site_bucket" {
  name          = "site-bucket"
  location      = "US"
  force_destroy = true
}
```

The syntax of a **`resource` block** is:

```hcl
resource "<resource type>" "<resource name>" {
    # resource configuration
}
```

So, above, we're declaring a new `google_storage_bucket` resource in the project, and we're calling it `static_site_bucket`. There are a minimum of two required arguments for this resource type: `name` and `location`. The `name` is the name of the bucket, and the `location` is the region where the bucket will be created. The `force_destroy` argument is optional, but it's set to `true` here to allow Terraform to delete the bucket even if it's not empty.

> **Note**: I'm getting an idea of what the possible arguments are for this resource type by looking at the [Google Cloud provider documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket). The Provider docs are *very valuable* resources for understanding what you can do with a given resource type. It's basically the only way to use Terraform effectively.

Now that we actually have a `resource` in our project, we can meaningfully run `terraform plan` to get a preview of what Terraform thinks it will need to provision to deploy our project.

<details>

<summary><code>terraform plan</code> output (error!)</summary>

<div markdown=1>

```bash
$ terraform plan

  Planning failed. Terraform encountered an error while generating this   plan.
  
  ╷
  │ Error: Invalid provider configuration
  │ 
  │ Provider "registry.terraform.io/hashicorp/google" requires explicit 
  configuration. Add a provider block to the root module and configure the 
  provider's required arguments as described in the
  │ provider documentation.
  │ 
  ╵
  ╷
  │ Error: Attempted to load application default credentials since neither 
  `credentials` nor `access_token` was set in the provider block.  No 
  credentials loaded. To use your gcloud credentials, run 'gcloud auth 
  application-default login'. Original error: google: could not find 
  default credentials. See https://cloud.google.com/docs/authentication/
  external/set-up-adc for more information
  │ 
  │   with provider["registry.terraform.io/hashicorp/google"],
  │   on <empty> line 0:
  │   (source code not available)
  │ 

```
</div>

</details>

Ok, so two issues. The first one ("Invalid provider configuration") is because we haven't actually configured the Google Cloud provider in our project. Whoops! That's an easy fix we'll get to shortly.

The second one ("Attempted to load application default credentials") is because Terraform doesn't know how to authenticate with Google Cloud. We went through a manual process to authenticate with `gcloud` earlier, but Terraform doesn't know about that. We need to tell Terraform to use the same credentials that `gcloud` is using. Thankfully, they give us a really easy command to just run to set up Terraform:

```bash
gcloud auth application-default login
```

This command will cache some authenticated credentials on your local filesystem which Terraform will pick up for use in authenticating with Google Cloud. This is a one-time setup, so you shouldn't need to run this command again unless you change your Google Cloud credentials.

Now let's create that provider configuration in our Terraform project. I like putting these in a dedicated `providers.tf` file, with one or more **`provider` blocks** defined in it:

```hcl
provider "google" {
  project = "davids-static-site"
  region  = "us-west2"
}
```

This is all that's strictly needed for Terraform to be able to use the Google Cloud provider. The `project` argument is the name of the Google Cloud project we created earlier, and the `region` argument is the default region that resources will be created in. This is a good default to set, but it can be overridden on a per-resource basis if necessary.

Now that we have this provider configuration, we can run `terraform plan` again to see what Terraform thinks it needs to do to deploy our project.

<details>

<summary><code>terraform plan</code> output</summary>

<div markdown=1>

```bash
$ terraform plan

  Terraform used the selected providers to generate the following execution 
  plan. Resource actions are indicated with the following symbols:
    + create
  
  Terraform will perform the following actions:
  
    # google_storage_bucket.static_site_bucket will be created
    + resource "google_storage_bucket" "static_site_bucket" {
        + effective_labels            = {
            + "goog-terraform-provisioned" = "true"
          }
        + force_destroy               = true
        + id                          = (known after apply)
        + location                    = "US"
        + name                        = "site-bucket"
        + project                     = (known after apply)
        + project_number              = (known after apply)
        + public_access_prevention    = (known after apply)
        + rpo                         = (known after apply)
        + self_link                   = (known after apply)
        + storage_class               = "STANDARD"
        + terraform_labels            = {
            + "goog-terraform-provisioned" = "true"
          }
        + uniform_bucket_level_access = (known after apply)
        + url                         = (known after apply)
  
        + soft_delete_policy (known after apply)
  
        + versioning (known after apply)
  
        + website (known after apply)
      }
  
  Plan: 1 to add, 0 to change, 0 to destroy.
```

</div>

</details>

Lovely! It correctly sees that, according to our project specifications, running `terraform apply` ought to create a GCS storage bucket. It seems to also pick up the configurations we set in the `bucket.tf` file, like the `name` and `location` of the bucket.

Do we dare try running `terraform apply`? This CLI command actually executes the stated plan, submitting the necessary API requests to Google Cloud to create the resources we've specified (in this case, just a GCS bucket).

<details>

<summary><code>terraform apply</code> output (error!)</summary>

<div markdown=1>

```bash
$ terraform apply

  ...
  google_storage_bucket.static_site_bucket: Creating...
  ╷
  │ Error: googleapi: Error 409: The requested bucket name is not 
  available. The bucket namespace is shared by all users of the system. 
  Please select a different name and try again., conflict
  │ 
  │   with google_storage_bucket.static_site_bucket,
  │   on bucket.tf line 1, in resource "google_storage_bucket"   "static_site_bucket":
  │    1: resource "google_storage_bucket" "static_site_bucket" {
  │ 
  ╵
```

</div>

</details>

Well that wasn't expected. Let's take a moment to discuss the way Google Cloud Storage buckets work.

### The issue with GCS buckets

This is frankly the most outrageous design decision I've seen on the part of the GCP team, especially coming from AWS where you can choose your bucket names pretty freely.

In GCP, the bucket namespace is *global* - if somebody else has already named a GCS bucket `site-bucket` (the name we were trying to use), then we can't use that name. That means that everyone has to come up with a globally unique name for their buckets, which is a bit of a pain point. Some users of GCP suggest using a UUID or other unique identifier in the bucket name to ensure uniqueness, then using prefixing or suffixing to add a human readable component to the name.

Is there a way to incorporate some sort of randomness / UUID generation into our Terraform project to ensure that we can always create a bucket with a unique name? With one quick Google search, we will learn that is possible by...

## Utilizing Terraform's `random` provider

Just like there is a `google` *Provider* responsible for managing Google Cloud resources, *Providers* are a more general concept in Terraform. Some providers may do things locally on your system, or talk to non-cloud services. The `random` provider is one such provider, which can generate random values for use in your Terraform project. It treats a small program which can be used to repeatably generate random values as a resource which is provisioned and maintained by Terraform, even though it's all actually happening locally on your machine.

Because it's just a provider like `google`, we'll treat it similarly and add entries to `versions.tf` and `providers.tf` to configure it:

```hcl
# versions.tf
terraform {
  ...
  required_providers {
    ...
    random = {
      source  = "hashicorp/random"
      version = "3.7.1"
    }
  }
}
```

```hcl
# providers.tf
provider "random" {
  # No configuration needed for the random provider
}
```

Now that we have the `random` provider configured, we can use it to generate a random UUID for the bucket name in our `bucket.tf` file. I'll still opt to suffix the random string with "site-bucket" so it's somewhat identifiable within our project.

```hcl
# bucket.tf
resource "random_uuid" "bucket_uuid" {}

resource "google_storage_bucket" "static_site_bucket" {
  name          = "${random_uuid.bucket_uuid.result}-site-bucket"
  location      = "US"
  force_destroy = true
}
```

> **Syntax note**: It's ubiquitous in Terraform to use string-formatting syntax `${}` to interpolate values into strings. This is how we're able to use the `random_uuid.bucket_uuid.result` value in the `name` attribute of the `google_storage_bucket` resource.

Since we just added a new provider to the project, we'll need to run `terraform init` again to download the `random` provider plugin into our project's local `.terraform` cache. After running that, we'll be able to check the impact on our Terraform plan by running `terraform plan` again:

<details>

<summary><code>terraform plan</code> output</summary>

<div markdown=1>

```bash
$ terraform plan
  
  Terraform used the selected providers to generate the following execution   plan. Resource actions are indicated with the following symbols:
    + create
  
  Terraform will perform the following actions:
  
    # google_storage_bucket.static_site_bucket will be created
    + resource "google_storage_bucket" "static_site_bucket" {
        + effective_labels            = {
            + "goog-terraform-provisioned" = "true"
          }
        + force_destroy               = true
        + id                          = (known after apply)
        + location                    = "US"
        + name                        = (known after apply)
        + project                     = (known after apply)
        + project_number              = (known after apply)
        + public_access_prevention    = (known after apply)
        + rpo                         = (known after apply)
        + self_link                   = (known after apply)
        + storage_class               = "STANDARD"
        + terraform_labels            = {
            + "goog-terraform-provisioned" = "true"
          }
        + uniform_bucket_level_access = (known after apply)
        + url                         = (known after apply)
  
        + soft_delete_policy (known after apply)
  
        + versioning (known after apply)
  
        + website (known after apply)
      }
  
    # random_uuid.bucket_uuid will be created
    + resource "random_uuid" "bucket_uuid" {
        + id     = (known after apply)
        + result = (known after apply)
      }
  
  Plan: 2 to add, 0 to change, 0 to destroy.
```

</div>

</details>

Note that Terraform identifies that we addeed a `random_uuid` resource to the project, which will be created as a part of the project. This explains why the `google_storage_bucket` resource now has a `name` attribute that is `(known after apply)` - it will be set to the result of the `random_uuid` resource after it's created (with our suffix appended).

> **Fair warning**: from here on out, you will officially start being billed for the resources you're provisioning in GCP. Up until this point we've been unsuccessful in creating any resources, so no costs were incurred. Starting with the following step, we will be creating resources in GCP, so you will start to incur costs.

Now we can give `terraform apply` a shot!

<details>

<summary><code>terraform apply</code> output</summary>

<div markdown=1>

```bash
$ terraform apply

  ...
  random_uuid.bucket_uuid: Creating...
  random_uuid.bucket_uuid: Creation complete after 0s   [id=5c01e5eb-1bed-5c2e-9a89-1570b1b405de]
  google_storage_bucket.static_site_bucket: Creating...
  google_storage_bucket.static_site_bucket: Creation complete after 2s [id=5c01e5eb-1bed-5c2e-9a89-1570b1b405de-site-bucket]
```

</div>

</details>

Done! We've successfully created a GCS bucket in GCP using Terraform. We can verify this by checking the Google Cloud Console, or by running `gsutil` commands to interact with the bucket. Specifically, if you run `gsutil ls`, it will list the buckets in your project:

```bash
$ gsutil ls
  gs://5c01e5eb-1bed-5c2e-9a89-1570b1b405de-site-bucket/
```

And there it is! Our bucket is listed in the output of the `gsutil ls` command. We haven't quite made it to the point where there's a static site we can visit and see content. But let's return back to this for another article later on to discuss how to actually upload content to the bucket and configure it to serve a static site publicly.

## Closing note

In the mean-time, we've still provisioned a GCS bucket in GCP. Since I'm not planning on using it for anything between now and the next article, I'll go ahead clean up after myself with the simple Terraform command, `terraform destroy`. This is one of the nicest things about Terraform in my opinion - everything you can provision, you can also destroy using a single, unified interface.

<details>

<summary><code>terraform destroy</code> output</summary>

<div markdown=1>

```bash
$ terraform destroy
  random_uuid.bucket_uuid: Refreshing state... [id=5c01e5eb-1bed-5c2e-9a89-1570b1b405de]
  google_storage_bucket.static_site_bucket: Refreshing state... [id=5c01e5eb-1bed-5c2e-9a89-1570b1b405de-site-bucket]
  ...
  google_storage_bucket.static_site_bucket: Destroying... [id=5c01e5eb-1bed-5c2e-9a89-1570b1b405de-site-bucket]
  google_storage_bucket.static_site_bucket: Destruction complete after 1s
  random_uuid.bucket_uuid: Destroying... [id=5c01e5eb-1bed-5c2e-9a89-1570b1b405de]
  random_uuid.bucket_uuid: Destruction complete after 0s
```

</div>

</details>

I can confirm that it's cleaned up by noting the empty result when I try `gsutil ls` again. Nice - now I can rest easy knowing that I'm not being billed for any resources in GCP. I can always come back to this project and run `terraform apply` to re-provision the bucket if I need to.
