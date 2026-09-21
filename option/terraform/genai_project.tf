resource "oci_generative_ai_project" "starter_genai_project" {
	description = "${var.prefix}-genai-project"
    display_name = "${var.prefix}-genai-project"	
	compartment_id = local.lz_app_cmp_ocid
	freeform_tags = local.freeform_tags
}

locals {
    local_project_ocid = oci_generative_ai_project.starter_genai_project.id
}
