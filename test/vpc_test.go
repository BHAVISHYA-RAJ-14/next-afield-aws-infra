package test

import (
	"testing"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVpcModule(t *testing.T) {
	// Retryable errors in case of temporary AWS API timeouts
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// Pointing directly to our isolated VPC module
		TerraformDir: "../modules/vpc",
		
		// Passing test-specific variables
		Vars: map[string]interface{}{
			"vpc_name":           "terratest-vpc-automated",
			"environment":        "test",
			"cidr_block":         "10.10.0.0/16",
			"azs":                []string{"us-east-1a", "us-east-1b"},
			"private_subnets":    []string{"10.10.1.0/24", "10.10.2.0/24"},
			"public_subnets":     []string{"10.10.101.0/24", "10.10.102.0/24"},
			"enable_nat_gateway": false,
			"single_nat_gateway": false,
		},
	})

	// Defer ensures terraform destroy is called at the very end, even if the test fails
	defer terraform.Destroy(t, terraformOptions)

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Extract the VPC ID output and assert it is not empty
	vpcId := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotNil(t, vpcId)
}
