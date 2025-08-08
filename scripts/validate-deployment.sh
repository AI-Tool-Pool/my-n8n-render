#!/bin/bash

# Render Deployment Validation Script
# Validates all configurations before deployment to Render

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Render Deployment Validation${NC}"
echo "=================================="

# Initialize validation counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNINGS=0

validate_check() {
    local result=$1
    local check_name="$2"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [[ $result -eq 0 ]]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        echo -e "✅ ${check_name}"
    else
        echo -e "❌ ${check_name}"
    fi
}

validate_warning() {
    local check_name="$1"
    WARNINGS=$((WARNINGS + 1))
    echo -e "⚠️  ${check_name}"
}

# Check 1: Dockerfile compatibility
echo -e "\n${BLUE}📋 Dockerfile Validation${NC}"
if grep -q "node:20-alpine" Dockerfile && grep -q "bash" Dockerfile && grep -q "curl" Dockerfile; then
    validate_check 0 "Dockerfile uses Alpine with shell support"
else
    validate_check 1 "Dockerfile missing essential runtime dependencies"
fi

if grep -q "node:node" Dockerfile; then
    validate_check 0 "Dockerfile uses correct node user"
else
    validate_check 1 "Dockerfile user configuration incorrect"
fi

if grep -q "max-old-space-size=400" Dockerfile; then
    validate_check 0 "Memory allocation optimized for free tier (400MB)"
else
    validate_check 1 "Memory allocation not optimized for free tier"
fi

# Check 2: render.yaml validation
echo -e "\n${BLUE}📋 render.yaml Validation${NC}"
if [[ -f "render.yaml" ]]; then
    validate_check 0 "render.yaml file exists"
    
    if grep -q "plan: free" render.yaml; then
        validate_check 0 "Free tier plan configured"
    else
        validate_check 1 "Free tier plan not configured"
    fi
    
    if grep -q "healthCheckPath: /healthz" render.yaml; then
        validate_check 0 "Health check path configured"
    else
        validate_check 1 "Health check path missing"
    fi
    
    # Count environment variables
    env_var_count=$(grep -c "key:" render.yaml || echo "0")
    if [[ $env_var_count -ge 25 ]]; then
        validate_check 0 "Sufficient environment variables configured ($env_var_count)"
    else
        validate_check 1 "Insufficient environment variables ($env_var_count < 25)"
    fi
else
    validate_check 1 "render.yaml file missing"
fi

# Check 3: Health check script
echo -e "\n${BLUE}📋 Health Check Validation${NC}"
if [[ -f "check_health.sh" ]]; then
    validate_check 0 "Health check script exists"
    
    if grep -q "/healthz" check_health.sh; then
        validate_check 0 "Health check supports /healthz endpoint"
    else
        validate_check 1 "Health check missing /healthz endpoint support"
    fi
    
    if [[ -x "check_health.sh" ]]; then
        validate_check 0 "Health check script is executable"
    else
        validate_check 1 "Health check script not executable"
    fi
else
    validate_check 1 "Health check script missing"
fi

# Check 4: Configuration files
echo -e "\n${BLUE}📋 Configuration Files Validation${NC}"
if [[ -f "config/n8n-config.json" ]]; then
    validate_check 0 "n8n configuration file exists"
    
    if grep -q "DB_POSTGRESDB_HOST" config/n8n-config.json; then
        validate_check 0 "Database configuration uses correct variable names"
    else
        validate_check 1 "Database configuration uses incorrect variable names"
    fi
    
    if grep -q "poolSize.*[12]" config/n8n-config.json; then
        validate_check 0 "Database pool size optimized for free tier"
    else
        validate_warning "Database pool size may be too high for free tier"
    fi
else
    validate_check 1 "n8n configuration file missing"
fi

# Check 5: Entrypoint script
echo -e "\n${BLUE}📋 Entrypoint Script Validation${NC}"
if [[ -f "entrypoint.sh" ]]; then
    validate_check 0 "Entrypoint script exists"
    
    if grep -q "max-old-space-size=400" entrypoint.sh; then
        validate_check 0 "Memory optimization configured in entrypoint"
    else
        validate_check 1 "Memory optimization missing in entrypoint"
    fi
    
    if grep -q "EXECUTIONS_TIMEOUT.*600" entrypoint.sh; then
        validate_check 0 "Execution timeout optimized for free tier"
    else
        validate_check 1 "Execution timeout not optimized"
    fi
    
    if [[ -x "entrypoint.sh" ]]; then
        validate_check 0 "Entrypoint script is executable"
    else
        validate_check 1 "Entrypoint script not executable"
    fi
else
    validate_check 1 "Entrypoint script missing"
fi

# Check 6: Workflow compatibility
echo -e "\n${BLUE}📋 Workflow Compatibility${NC}"
if [[ -d "workflows" ]]; then
    total_workflows=$(find workflows -name "*.json" | wc -l)
    validate_check 0 "Workflows directory contains $total_workflows workflows"
    
    # Count large workflows (>50 nodes) - simplified check by file size
    large_workflows=$(find workflows -name "*.json" -size +10k | wc -l)
    compatible_workflows=$((total_workflows - large_workflows))
    
    if [[ $large_workflows -gt 0 ]]; then
        validate_warning "$large_workflows large workflows may impact free tier performance"
    fi
    
    validate_check 0 "$compatible_workflows workflows optimized for free tier"
else
    validate_check 1 "Workflows directory missing"
fi

# Check 7: Required scripts
echo -e "\n${BLUE}📋 Required Scripts Validation${NC}"
required_scripts=("scripts/database-adapter.sh" "scripts/setup-database.sh")

for script in "${required_scripts[@]}"; do
    if [[ -f "$script" ]]; then
        validate_check 0 "$(basename "$script") exists"
        if [[ -x "$script" ]]; then
            validate_check 0 "$(basename "$script") is executable"
        else
            validate_check 1 "$(basename "$script") not executable"
        fi
    else
        validate_check 1 "$(basename "$script") missing"
    fi
done

# Final Summary
echo -e "\n${BLUE}📊 VALIDATION SUMMARY${NC}"
echo "=================================="
echo -e "Total checks: $TOTAL_CHECKS"
echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Failed: ${RED}$((TOTAL_CHECKS - PASSED_CHECKS))${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"

success_rate=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
echo -e "Success rate: $success_rate%"

if [[ $PASSED_CHECKS -eq $TOTAL_CHECKS ]]; then
    echo -e "\n${GREEN}🎉 ALL VALIDATIONS PASSED!${NC}"
    echo -e "${GREEN}✅ Ready for Render deployment${NC}"
    exit 0
elif [[ $success_rate -ge 90 ]]; then
    echo -e "\n${YELLOW}⚠️  MOSTLY READY FOR DEPLOYMENT${NC}"
    echo -e "${YELLOW}Minor issues found - review and fix before deployment${NC}"
    exit 1
else
    echo -e "\n${RED}❌ DEPLOYMENT NOT READY${NC}"
    echo -e "${RED}Critical issues found - fix before deployment${NC}"
    exit 2
fi
