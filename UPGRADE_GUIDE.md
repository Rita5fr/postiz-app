# Postiz Fork Upgrade Guide

This guide documents all custom changes made to the `Rita5fr/postiz-app` fork and the procedure to safely merge upstream updates from `gitroomhq/postiz-app`.

---

## Custom Changes to Preserve

### 1. Railway Healthcheck Endpoint
**Files:** `railway.toml`, `var/docker/nginx.conf`

**What:** Added `/health` endpoint served directly by Nginx (returns 200 instantly). Changed Railway healthcheck path from `/` to `/health`.

**Why:** The default `/` healthcheck proxies to the Node.js frontend which takes 3-5 minutes to start. This caused 90% of deployments to fail the 5-minute healthcheck window.

**railway.toml:**
```toml
healthcheckPath = "/health"   # was "/"
healthcheckTimeout = 600
```

**var/docker/nginx.conf** (inside the `server` block, before other locations):
```nginx
location /health {
    access_log off;
    return 200 'OK';
    add_header Content-Type text/plain;
}
```

---

### 2. Prisma Connection Pool Fix
**File:** `libraries/nestjs-libraries/src/database/prisma/prisma.service.ts`

**What:** Added `connection_limit` and `pool_timeout` to the database URL to prevent PostgreSQL connection exhaustion.

**Why:** On Railway's shared PostgreSQL, the default pool size caused 502 errors under load.

**Code:**
```typescript
const url = new URL(process.env.DATABASE_URL!);
url.searchParams.set('connection_limit', '5');
url.searchParams.set('pool_timeout', '10');
```

---

### 3. Browser-Like Headers for Profile Picture Download
**File:** `libraries/nestjs-libraries/src/upload/local.storage.ts`

**What:** Added browser-like `User-Agent` and `Accept` headers to the profile picture download request.

**Why:** Social media CDNs (LinkedIn, etc.) return 403 Forbidden when requests lack browser headers.

**Code:**
```typescript
const loadImage = await fetch(path, {
  headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ...',
    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
  },
});
```

---

### 4. Non-Fatal Profile Picture Download
**File:** `libraries/nestjs-libraries/src/database/prisma/integrations/integration.service.ts`

**What:** Made profile picture download non-fatal with `.catch()` fallback.

**Why:** If the profile picture download fails, the integration should still be created.

---

### 5. Docker Compose Overrides
**File:** `docker-compose.yaml`

**What:** Custom compose configuration with `!override` tag for `depends_on` to prevent merge issues with disabled services.

---

### 6. Install Script & Caddy
**Files:** `install.sh`, `postiz`, `Caddyfile`

**What:** Auto-installer script with Caddy reverse proxy for self-hosting with auto-SSL.

---

## Upgrade Procedure

### Step 1: Fetch upstream
```bash
cd postiz-app
git fetch upstream
```

If upstream remote doesn't exist:
```bash
git remote add upstream https://github.com/gitroomhq/postiz-app.git
git fetch upstream
```

### Step 2: Merge
```bash
git merge upstream/main --no-edit
```

### Step 3: Resolve Conflicts
If conflicts occur, check each file:
```bash
git diff --name-only --diff-filter=U
```

For each conflicted file, open it and look for `<<<<<<<` markers. Keep our custom changes while accepting upstream improvements.

**Most likely conflict files:**
- `var/docker/nginx.conf` — re-add the `/health` location block
- `railway.toml` — ensure `healthcheckPath = "/health"` 
- `libraries/.../prisma.service.ts` — re-add connection pool params
- `libraries/.../local.storage.ts` — re-add browser-like headers
- `libraries/.../integration.service.ts` — re-add `.catch()` fallback

### Step 4: Verify Custom Changes
After resolving conflicts, verify all changes are intact:
```bash
# Check healthcheck
grep -n "health" railway.toml
grep -n "health" var/docker/nginx.conf

# Check prisma pool
grep -n "connection_limit" libraries/nestjs-libraries/src/database/prisma/prisma.service.ts

# Check browser headers  
grep -n "User-Agent" libraries/nestjs-libraries/src/upload/local.storage.ts

# Check non-fatal download
grep -n "catch" libraries/nestjs-libraries/src/database/prisma/integrations/integration.service.ts
```

### Step 5: Commit and Push
```bash
git add .
git commit --no-edit   # or with a custom message
git push
```

### Step 6: Deploy
Railway will auto-deploy if connected to the GitHub repo. Otherwise:
```bash
railway up --service postiz-app --detach
```
