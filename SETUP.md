# Setup Instructions

## Push to GitHub

From this directory (`/home/ethanwee/pytorch-rocm-testing`):

### Option 1: Create a new repository using GitHub CLI

```bash
# Create a new repository (choose public or private)
gh repo create pytorch-rocm-713-testing --public --source=. --remote=origin --push

# Or for a private repo
gh repo create pytorch-rocm-713-testing --private --source=. --remote=origin --push
```

### Option 2: Create repository via GitHub web UI

1. Go to https://github.com/new
2. Create a repository named `pytorch-rocm-713-testing` (or your preferred name)
3. **Do not** initialize with README, .gitignore, or license
4. Copy the repository URL
5. Run these commands:

```bash
git remote add origin <repository-url>
git branch -M main
git push -u origin main
```

## Clone on Each Test Machine

Once pushed to GitHub, on each test machine:

```bash
# Clone the repository
git clone https://github.com/<your-username>/pytorch-rocm-713-testing
cd pytorch-rocm-713-testing

# Make scripts executable (if needed)
chmod +x *.sh

# Run tests
./pull_and_test_dockers.sh 2.9 gfx942  # (adjust version and arch)
```

## Updating Scripts

If you need to update scripts after pushing:

```bash
# Make changes to scripts
# Then commit and push
git add .
git commit -m "Update: description of changes"
git push

# On test machines, pull updates
git pull
```
