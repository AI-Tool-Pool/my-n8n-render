# Deploy n8n on Render

This guide walks through deploying [n8n](https://n8n.io/) on Render using the official [n8n Docker image](https://hub.docker.com/r/n8nio/n8n).

Use n8n to intelligently automate sequences of tasks across a wide variety of applications: post Slack messages, trigger CI/CD pipelines, create support tickets, and much more.

## First, choose a storage method

Your n8n instance can use one of two methods to store workflow data on Render. The method you choose determines how you configure your deployment:

<table class="apiref">
<thead>
<tr>
<th>Storage Method</th>
<th>Description</th>
</tr>
</thead>
<tbody>
<tr>
<td>

[**Render Postgres**](#setup-render-postgres) (recommended)

</td>
<td>

Store workflow data in a PostgreSQL database separate from your n8n instance.

**We recommend this strategy for the following reasons:**

- You can get started for free (persistent disks require a paid service instance).
- You can redeploy your n8n instance with [zero downtime](/docs/deploys#zero-downtime-deploys) (a persistent disk prevents zero-downtime deploys).
- You can run multiple n8n instances that share workflow data, such as in [queue mode](https://docs.n8n.io/hosting/scaling/queue-mode/) (a persistent disk is accessible by only a single instance).

</td>
</tr>
<tr>
<td>

[**Persistent disk**](#setup-persistent-disk)

</td>
<td>

Store workflow data in SQLite on a disk attached to your n8n instance.

This setup is more straightforward, because you don't need to connect your n8n instance to an external database. _However_, persistent disks require a paid service instance and prevent horizontal scaling.

See above for more details on why we recommend using Render Postgres instead.

</td>
</tr>
</tbody>
</table>

After you choose a storage method, follow the corresponding setup instructions below.

## Setup: Render Postgres

If you'll store workflow data in a Render Postgres database, your n8n deployment will consist of two Render resources:

- A [web service](/docs/web-services) that pulls and runs the n8n Docker image
- A [Render Postgres database](/docs/postgresql) that stores your n8n workflow data

<info-block>

**This setup uses [**free Render instance types**](/docs/free).**

Free web services spin down after 15 minutes of inactivity, and free Render Postgres databases expire after 30 days.

After you get up and running with n8n, you can [upgrade your instances](#4-upgrade-your-instances) to remove these limitations and improve performance.

</info-block>

### 1. Sign up for Render

Signing up is fast and free:

<button-link href="https://dashboard.render.com/register">Sign up for Render</button-link>

### 2. Copy the example template

To simplify connecting your n8n instance to its database, we've created a template repo that enables you to deploy both resources together using a [Render Blueprint](/docs/infrastructure-as-code).

1. Open the [render-examples/n8n template](https://github.com/render-examples/n8n) on GitHub.
2. Click **Use this template > Create a new repository** in the top right.
3. In the form that appears, set configuration options for your new repo, then click **Create repository**.

### 3. Create a Render Blueprint

Your newly created repo contains a `render.yaml` file that defines both your n8n web service and its database:

```yaml
# An excerpt from render.yaml
services:
  - type: web
    plan: free
    runtime: image
    name: n8n-service
    image:
      url: docker.io/n8nio/n8n:latest
    # …
```

<info-block>

The full file in your repo includes helpful comments describing the purpose of included fields.

</info-block>

By defining our two resources this way, we can configure and deploy them together using [Blueprints](/docs/infrastructure-as-code), Render's infrastructure-as-code model:

1. In the [Render Dashboard](https://dashboard.render.com), click **New > Blueprint**:

   

   <img src="#" alt="Selecting Blueprint from the New menu in the Render Dashboard" />

   

2. If you haven't yet, connect your GitHub account to Render. This enables Render to fetch the `render.yaml` file from your new repo.
3. Under **Connect a repository**, click the **Connect** button for the repo you created earlier.

   This opens a Blueprint creation form that lists the resources Render will create from your `render.yaml` file:

   

   <img src="#" alt="The Blueprint creation form in the Render Dashboard" />

   

4. Provide a **Blueprint Name** and confirm that you're pulling the **Branch** you expect from your repo.

5. Click **Deploy Blueprint**.

   Your Blueprint kicks off its first **sync**, which you can follow along with:

   

   <img src="#" alt="Proceeding through a Blueprint sync in the Render Dashboard" />

   

   As each resource is created, a green checkmark appears next to it.

   <details>

   <summary>

   **+ Database creation failed?**

   </summary>

   Your workspace might already have a free Render Postgres database (each workspace is limited to one). If so, do one of the following:

   - Delete your existing free database in the Render Dashboard, then retry syncing the Blueprint.
   - Update your `render.yaml` file to [use a paid instance type](#4-upgrade-your-instances) for the database, then push the update to your repo to trigger a new sync.

   </details>

6. After both resources become available, navigate to your new web service's page in the Render Dashboard. Its `onrender.com` URL appears at the top:

   

   <img src="#" alt="The web service URL in the Render Dashboard" />

   

   Visit this URL to access your n8n instance:

   

   <img src="#" alt="The empty-state n8n homepage" />

   

You're up and running with n8n on Render! Before you get started creating workflows, we recommend the following:

- [Upgrade to paid instances](#4-upgrade-your-instances) before your free Render Postgres database expires.
- Review the [additional configuration](#additional-configuration) below.

### 4. Upgrade your instances

As specified by default in `render.yaml`, both your n8n web service and Render Postgres database use [free instance types](/docs/free), which have important limitations. **Most critically, your free database will expire after 30 days.**

After you're up and running with n8n, you can upgrade these services to use paid instance types. Change the `plan` field for each service to the desired instance type, then push your changes:

```yaml
# An excerpt from render.yaml
services:
  - type: web
    plan: standard # highlight-line
    # …
databases:
  - name: n8n-db
    plan: basic-256mb # highlight-line


  # Optionally increase database storage to any
  # multiple of 5 GB by setting diskSizeGB:
  # diskSizeGB: 5
```

- For n8n, we recommend running your web service on the `standard` instance type or larger.
  - Otherwise, n8n might encounter performance issues.
- The `basic-256mb` is the smallest paid Render Postgres instance type and is usually sufficient for your n8n database.

See all supported `plan` values for [web services](/docs/blueprint-spec#plan) and [databases](/docs/blueprint-spec#plan-1).

## Setup: Persistent disk

If you'll store workflow data directly with your n8n instance, you create a Render [web service](/docs/web-services) and attach a [persistent disk](/docs/disks) to it.

Note that persistent disks require a paid service instance. To get started for free, you can use [Render Postgres](#setup-render-postgres) instead.

<help-block>

**Why attach a persistent disk?**

By default, Render services have an [ephemeral filesystem](/docs/deploys#ephemeral-filesystem), which means that all changes to local files are lost whenever the instance is redeployed. A persistent disk enables you to retain filesystem changes across deploys.

</help-block>

### 1. Sign up for Render

Signing up is fast and free:

<button-link href="https://dashboard.render.com/register">Sign up for Render</button-link>

### 2. Create your n8n web service

1. In the [Render Dashboard](https://dashboard.render.com), click **New > Web Service**:

   

   <img src="#" alt="Creating a new web service in the Render Dashboard" />

   

2. Under **Source Code**, click **Existing Image**:

   

   <img src="#" alt="Deploying a Docker image in the Render Dashboard" />

   

3. Provide the following **Image URL** and click **Connect**:

   ```
   docker.io/n8nio/n8n:latest
   ```

   - You can specify a tag or digest besides `latest` if you prefer. For details, see [Pin to a specific n8n version](#pin-to-a-specific-n8n-version).

4. Provide a **Name** for your web service and specify which **Region** you'll deploy it to.

5. Select an **Instance Type** for your web service. You can select any instance type besides **Free** (which doesn't support persistent disks).

6. Under **Environment Variables**, add a `PORT` variable with a value of `5678`. This is the default port that n8n listens on.

   - This step isn't strictly necessary (Render can detect your service's HTTP port automatically), but it speeds up your first deploy.

7. Expand the **Advanced** dropdown at the bottom of the form and find the **Disk** section.

8. Click **Add disk**. The following fields appear:

   

   <img src="#" alt="Adding a persistent disk to an n8n web service" />

   

9. Set your disk's **Mount path** to `/home/node`. By default, n8n will store its data in a `.n8n` directory under this path.

   - **Only data under the mount path is persisted across deploys!** Changes to other parts of the filesystem are lost when the service is redeployed.
   - You can store n8n data in a different directory by setting the [`N8N_USER_FOLDER` environment variable](https://docs.n8n.io/hosting/configuration/configuration-examples/user-folder/). If you do, modify your disk's mount path to match.

10. Set the disk's **Size** to 1 GB for now. You can increase this size later as needed.

11. Click **Deploy Web Service**.

12. After the deploy completes, navigate to your new web service's page in the Render Dashboard. Its `onrender.com` URL appears at the top:

    

    <img src="#" alt="The web service URL in the Render Dashboard" />

    

    Visit this URL to access your n8n instance:

    

    <img src="#" alt="The empty-state n8n homepage" />

    

You're up and running with n8n on Render! Before you get started creating workflows, we recommend reviewing the [additional configuration](#additional-configuration) below.

## Additional configuration

Complete the following steps as needed after you complete the initial setup of your n8n instance.

### Set your webhook URL

If any of your n8n workflows will listen for incoming webhook notifications, you need to set the root URL for all webhook endpoints by adding an [environment variable](/docs/configure-environment-variables) to your web service:

1. From your n8n web service's page in the [Render Dashboard](https://dashboard.render.com), click **Environment** in the left pane.

   - If you're using Render Postgres, here you'll see all of the existing environment variables that were added as part of the Blueprint deployment (`DB_POSTGRESDB_DATABASE`, `DB_POSTGRESDB_PASSWORD`, and so on).

2. Under **Environment Variables**, click **Edit**, then **Add > New variable**.
3. Set the new variable's **Key** to `WEBHOOK_URL`.
4. Set the variable's **Value** to the service's `onrender.com` URL (e.g., `https://n8n-service-q975.onrender.com/`).
5. Click **Save and deploy**.

After the deploy completes, your `onrender.com` URL will be reflected in any webhook nodes you add to your workflows:



<img src="#" alt="Viewing n8n webhook URLs" />



### Pin to a specific n8n version

In both setup methods above, you deploy the version of n8n associated with the `latest` tag. This version changes over time, which might introduce breaking changes to your workflows.

You can instead pin your n8n version to a specific version. Select your setup method to view instructions for pinning your n8n version:

<tab-switcher>
<tab-switcher-item label="Blueprint (Render Postgres)">

In your repo's `render.yaml` file, specify an n8n version by providing its tag in the `image.url` field, like so:

```yaml
# An excerpt from render.yaml
services:
  - type: web
    image: # highlight-line
      url: docker.io/n8nio/n8n:1.83.2 #highlight-line
    # …
```

You can also pin to a specific _digest_, which ensures that your service always uses the _exact same_ image:

```yaml
# An excerpt from render.yaml
services:
  - type: web
    image: # highlight-line
      url: docker.io/n8nio/n8n@sha256:5288543ac4dc1ea7149a93e38a24989c913c9007dd2459f6c730ac247c4d958f #highlight-line
    # …
```

After you make this change, push it to your repo. Your Blueprint will automatically sync and deploy the newly specified n8n version.

</tab-switcher-item>
<tab-switcher-item label="Dashboard (persistent disk)">

1. In the [Render Dashboard](https://dashboard.render.com), open your n8n web service's **Settings** page.
2. Scroll down to the **Image** section and click **Edit**.

   The following dialog appears:

   

   <img src="#" alt="Updating the n8n image tag in the Render Dashboard" />

   

3. In the **Image URL** field, specify the n8n tag or digest you want to use, like so:

   ```
   docker.io/n8nio/n8n:1.83.2
   ```

   - You can also pin to a specific _digest_, which ensures that your service always uses the _exact same_ image:

   ```
   docker.io/n8nio/n8n@sha256:5288543ac4dc1ea7149a93e38a24989c913c9007dd2459f6c730ac247c4d958f
   ```

4. Click **Save Changes**. Your service will redeploy with the newly specified n8n version.

</tab-switcher-item>
</tab-switcher>