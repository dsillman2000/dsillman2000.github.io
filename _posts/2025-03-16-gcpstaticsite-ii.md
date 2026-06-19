---
layout: post
author: David Sillman
title: "TF-GCP II: Uploading static content to GCP storage"
---

In the last article, we were able to successfully deploy a Google Cloud Storage (GCS) bucket using Terraform. It was a little bit anticlimactic, since the only real indication that we had done anything at all was the output of `gsutil ls` showing that the bucket was created. In this article, we'll get closer to our goal of hosting a static site on GCS by getting our implementation to the point where there's actually a URL we can visit and see some static site content.

\\
First, we'll need to decide what that static content which is served from GCS will be.

## A basic "hello world" site, with Tailwind

For the purposes of this tutorial, we're not doing anything particularly fancy. In short, we're going to write a simple `index.html` file which, when viewed in the browser, looks half-decent. One of the ways we can do that in a low-effort way is by using [Tailwind CSS](https://tailwindcss.com/), a utility-first CSS framework that allows us to style our site entirely within HTML without needing to bother with CSS files.

This article isn't meant to go into depth about how Tailwind works, but I'll at least give a basic explanation of the [*utility classes*](https://tailwindcss.com/docs/styling-with-utility-classes) which we're using for our "hello world" example to make it look nice.

---

\\
First, I'll create a `content/` directory in my project folder which I'll use to store the static content for my site. Inside that directory, I'll create an `index.html` file with the following content:

```html
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hello, world!</title>
    <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.0.2/dist/tailwind.min.css" rel="stylesheet">
</head>
<!-- Body goes here -->

</html>
```

This is a super basic skeleton of an empty HTML page. The only thing we've set up is a link to the Tailwind CSS CDN, which will allow us to use Tailwind utility classes to style our site within the document. Additionally, I've added a `<title>` tag with the text "Hello, world!" which will be displayed in the browser tab.

\\
For the body, I let Copilot take the wheel and generate a really basic centered "Hello World" message:

```html
<body class="bg-gray-100 h-screen flex items-center justify-center">
    <h1 class="text-4xl text-gray-800">Hello World</h1>
</body>
```

You'll note the use of a bunch of non-sensical tokens like `bg-gray-100`, `items-center` and `text-4xl`. These are the Tailwind *utility classes* I mentioned earlier. They're a way of applying styles to elements in a way that's more readable and maintainable than writing CSS. For example, `bg-gray-100` sets the background color of the element to a light gray, `items-center` centers the content vertically, and `text-4xl` sets the text size to "quadruple extra large."

\\
When I open this HTML document from my local filesystem in a browser, I see a centered "Hello World" message in a nice, large font:

<img class="centered-image" src="/assets/images/content-index-html.png">

Looks like it will do the trick. For good measure, I'll make a copy of this file called `content/404.html`, replacing the "Hello World" message(s) with "404," to act as a fallback page in case the user tries to access a page that doesn't exist:

```html
...
<body class="bg-gray-100 h-screen flex items-center justify-center">
    <h1 class="text-4xl text-gray-800">404</h1>
</body>
...
```

\\
Now, let's get this content uploaded to our GCS bucket - but via Terraform, of course.

## GCS bucket object resources

I'm going to create a new dedicated Terraform file for managing the content of my GCS bucket. I'll called it `site_content.tf`. With the `google` provider, objects in cloud storage themselves can be provisioned as *resources* in Terraform. So, in this new `site_content.tf` file, I'll define two `google_storage_bucket_object` resources, one for each of the HTML files I created earlier:

```hcl
resource "google_storage_bucket_object" "index_html" {
  bucket       = google_storage_bucket.static_site_bucket.name
  name         = "index.html"
  source       = "content/index.html"
  content_type = "text/html"
}

resource "google_storage_bucket_object" "error_html" {
  bucket       = google_storage_bucket.static_site_bucket.name
  name         = "404.html"
  source       = "content/404.html"
  content_type = "text/html"
}
```

Ok, these resources look a little different from the ones we've been declaring in the previous article. You'll note that the `bucket` configuration is not being set to an explicit value. Rather, it's being set according to the `name` attribute of the `google_storage_bucket` resource we created in the last article, called `static_site_bucket`. So, the syntax for referencing attributes of other resources in Terraform is:

```hcl
# <resource_type>.<resource_name>.<attribute_name>
google_storage_bucket.static_site_bucket.name
```

You may ask, "why not just set the `bucket` attribute to the name of the bucket directly?" The answer is that this way, we can ensure that the `google_storage_bucket_object` resources are created in the same bucket as the `google_storage_bucket` resource, even if the name of the bucket changes. Moreover, Terraform also takes stock of referential dependencies between resources like this one, which helps it determine the correct order in which to create resources, and which resources can be provisioned in parallel. So, implicitly, we are telling Terraform that these new `google_storage_bucket_object` resources depend on the `google_storage_bucket` resource we created earlier, so they'll be created in sequence.

The `name` and `content_type` arguments tell GCP what to name the object in the bucket and what type of content it is, respectively. The `source` argument is the path to the file on the local filesystem which we want to upload to the bucket. In this case, it's the `index.html` and `404.html` files in the `content/` directory.

\\
We're finally ready to validate the execution plan with Terraform's `plan` command.

<details>
<summary><code>terraform plan</code> output</summary>
<div markdown=1>

```sh
$ terraform plan

  Terraform used the selected providers to generate the   following execution plan. Resource actions are indicated   with the following symbols:
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
  
        + website {
            + main_page_suffix = "index.html"
            + not_found_page   = "404.html"
          }
      }
  
    # google_storage_bucket_object.error_html will be created
    + resource "google_storage_bucket_object" "error_html" {
        + bucket         = (known after apply)
        + content        = (sensitive value)
        + content_type   = "text/html"
        + crc32c         = (known after apply)
        + detect_md5hash = "different hash"
        + generation     = (known after apply)
        + id             = (known after apply)
        + kms_key_name   = (known after apply)
        + md5hash        = (known after apply)
        + media_link     = (known after apply)
        + name           = "404.html"
        + output_name    = (known after apply)
        + self_link      = (known after apply)
        + source         = "content/404.html"
        + storage_class  = (known after apply)
      }
  
    # google_storage_bucket_object.index_html will be created
    + resource "google_storage_bucket_object" "index_html" {
        + bucket         = (known after apply)
        + content        = (sensitive value)
        + content_type   = "text/html"
        + crc32c         = (known after apply)
        + detect_md5hash = "different hash"
        + generation     = (known after apply)
        + id             = (known after apply)
        + kms_key_name   = (known after apply)
        + md5hash        = (known after apply)
        + media_link     = (known after apply)
        + name           = "index.html"
        + output_name    = (known after apply)
        + self_link      = (known after apply)
        + source         = "content/index.html"
        + storage_class  = (known after apply)
      }
  
    # random_uuid.bucket_uuid will be created
    + resource "random_uuid" "bucket_uuid" {
        + id     = (known after apply)
        + result = (known after apply)
      }
  
  Plan: 4 to add, 0 to change, 0 to destroy.
```

</div>
</details>

Recall that, at the end of the last article, I destroyed everything in my GCP project. So when I ran `terraform plan`, Terraform correctly queried the remote GCP state to determine that all of my resources need to be re-created. This is a good sign that our Terraform configuration is working as expected. We also see our expected `google_storage_bucket_object` resources being created, along with the `website` block in the `google_storage_bucket` resource. Let's apply the changes.

<details>
<summary><code>terraform apply</code> output</summary>
<div markdown=1>

```sh
$ terraform apply
  random_uuid.bucket_uuid: Creating...
  random_uuid.bucket_uuid: Creation complete after 0s   [id=be028675-b3cd-8fbd-c48a-3ddb6629ca7b]
  google_storage_bucket.static_site_bucket: Creating...
  google_storage_bucket.static_site_bucket: Creation complete   after 2s   [id=be028675-b3cd-8fbd-c48a-3ddb6629ca7b-site-bucket]
  google_storage_bucket_object.error_html: Creating...
  google_storage_bucket_object.index_html: Creating...
  google_storage_bucket_object.error_html: Creation complete   after 1s   [id=be028675-b3cd-8fbd-c48a-3ddb6629ca7b-site-bucket-404.  html]
  google_storage_bucket_object.index_html: Creation complete   after 1s   [id=be028675-b3cd-8fbd-c48a-3ddb6629ca7b-site-bucket-index.  html]
  
  Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

</div>
</details>

\\
I can once again confirm that the bucket is created with `gsutil ls`:

```sh
$ gsutil ls
gs://be028675-b3cd-8fbd-c48a-3ddb6629ca7b-site-bucket/
```

\\
Specifically, I can also see the objects in the bucket:

```sh
$ gsutil ls gs://be028675-b3cd-8fbd-c48a-3ddb6629ca7b-site-bucket/*
gs://be028675-b3cd-8fbd-c48a-3ddb6629ca7b-site-bucket/404.html
gs://be028675-b3cd-8fbd-c48a-3ddb6629ca7b-site-bucket/index.html
```

\\
It correctly identifies that we've uploaded the `index.html` and `404.html` files to the bucket. Now, let's see if we can access the site content via the bucket URL.

## Viewing the site content

To view the site content, I'll navigate to the URL of the bucket in my browser. The URL is in the format `https://<bucket-name>.storage.googleapis.com`. In this case, the bucket name is `be028675-b3cd-8fbd-c48a-3ddb6629ca7b-site-bucket`, so the URL is `https://be028675-b3cd-8fbd-c48a-3ddb6629ca7b-site-bucket.storage.googleapis.com/index.html`.

> **Note:** around this point in the exercise, I decided to destroy and re-apply my terraform project, which regenerated my UUID and bucket name. This may continue to happen insofar as randomness is involved in the generation of the bucket name. If you're following along, please overlook any discrepancies in the bucket name within and between articles.

When I navigate to this URL, I get an error message:

```xml
<Error>
    <Code>AccessDenied</Code>
    <Message>Access denied.</Message>
    <Details>Anonymous caller does not have storage.objects.get access to the Google Cloud Storage object. Permission 'storage.objects.get' denied on resource (or it may not exist).</Details>
</Error>
```

This indicates that, while we've successfully uploaded the content to the bucket, the bucket is not publicly accessible, and so our URL is returning an access denied error. We'll need to update the bucket's permissions to allow public access to the objects within it.

## Making the bucket public

To make the bucket public, we'll need to update the bucket's IAM policy to allow all users to view the objects within it. We can do this by adding a new `google_storage_bucket_iam_binding` resource to our Terraform configuration. I'll add this to our existing `bucket.tf` file:

```hcl
resource "google_storage_bucket_iam_binding" "public_read" {
  bucket = google_storage_bucket.static_site_bucket.name
  role   = "roles/storage.objectViewer"

  members = [
    "allUsers"
  ]
}
```

Note again that we are using the resource attribute reference syntax to set the `bucket` attribute to the name of the bucket we created earlier. This ensures that the IAM binding is created for the same bucket as the objects we uploaded.

The `role` attribute is set to `roles/storage.objectViewer`, which is a predefined IAM role that grants permission to view objects in a bucket. The `members` attribute is set to `allUsers`, which is a special identifier that represents all users, including anonymous users. This means that any user who visits the bucket URL will be able to view the objects within the bucket.

\\
We can check what the output of the `terraform plan` command looks like in order to confirm that the IAM binding will be created as expected for our bucket.

<details>
<summary><code>terraform plan</code> output</summary>
<div markdown=1>

```sh
$ terraform plan
  random_uuid.bucket_uuid: Refreshing state...   [id=edb54251-622d-bbec-5005-03ddfd1117fa]
  google_storage_bucket.static_site_bucket: Refreshing state...   [id=edb54251-622d-bbec-5005-03ddfd1117fa-site-bucket]
  google_storage_bucket_object.index_html: Refreshing state...   [id=edb54251-622d-bbec-5005-03ddfd1117fa-site-bucket-index.  html]
  google_storage_bucket_object.error_html: Refreshing state...   [id=edb54251-622d-bbec-5005-03ddfd1117fa-site-bucket-404.html]
  
  Terraform used the selected providers to generate the   following execution plan. Resource actions are indicated with   the following symbols:
    + create
  
  Terraform will perform the following actions:
  
    # google_storage_bucket_iam_binding.public_read will be   created
    + resource "google_storage_bucket_iam_binding" "public_read"   {
        + bucket  =   "edb54251-622d-bbec-5005-03ddfd1117fa-site-bucket"
        + etag    = (known after apply)
        + id      = (known after apply)
        + members = [
            + "allUsers",
          ]
        + role    = "roles/storage.objectViewer"
      }
  
  Plan: 1 to add, 0 to change, 0 to destroy.
```

</div>
</details>

\\
Looks good to me. Running `terraform apply`, we see that the policy binding gets successfully created.

```sh
$ terraform apply
  google_storage_bucket_iam_binding.public_read: Creating...
  google_storage_bucket_iam_binding.public_read: Creation complete after 5s [id=b/edb54251-622d-bbec-5005-03ddfd1117fa-site-bucket/roles/storage.objectViewer]
```

\\
Now, when I navigate to the bucket URL in my browser, I see the contents of the `index.html` file displayed:

<img class="centered-image" src="/assets/images/hello-world-site-shot.png">

Success! We've successfully uploaded static content to a GCS bucket and made it publicly accessible. I didn't promise that the URL used to access the website would necessarily be a nice one - so our goal was accomplished, as stated! In the next article, we'll take a moment to look back over the terraform we've written so far and see if there are any improvements we can make.

> **Note:** Once again, since I'm taking a break from this project, I'll clean up after myself to save myself any risk of incurring cloud costs while I'm not using the resources. As with the last article, it's easy to destroy the bucket and IAM binding with `terraform destroy`.