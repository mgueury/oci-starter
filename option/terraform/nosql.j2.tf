// NoSQL
{%- if nosql_ocid is defined %}
// Existing

{%- else %}   
resource "oci_nosql_table" "starter_nosql_table" {
  #Required
  compartment_id = var.compartment_ocid
  ddl_statement  = "CREATE TABLE IF NOT EXISTS dept(deptno INTEGER, dname STRING, loc STRING, PRIMARY KEY(SHARD(deptno)))"
  name           = "dept"

  table_limits {
    #Required
    max_read_units     = "10"
    max_write_units    = "1"
    max_storage_in_gbs = "1"
  }
}

resource "oci_identity_dynamic_group" "starter_nosql_dyngroup" {
  compartment_id = var.tenancy_ocid
  name           = "${var.prefix}-nosql-dyngroup"
  description    = "${var.prefix}-nosql-dyngroup"
  matching_rule  = "ANY {instance.compartment.id = '${var.compartment_ocid}', ALL {resource.type = 'fnfunc', resource.compartment.id ='${var.compartment_ocid} }, ALL {resource.type = 'computecontainerinstance', resource.compartment.id ='${var.compartment_ocid} }}"
  freeform_tags = local.freeform_tags
}

resource "oci_identity_policy" "starter_nosql_policy" {
  name           = "${var.prefix}-nosql-policy"
  description    = "${var.prefix}-nosql-policy"
  compartment_id = var.compartment_ocid
  statements = [
    "Allow dynamic-group ${var.prefix}-nosql-dyngroup to manage nosql-family in compartment id ${var.compartment_ocid}",
  ]
  freeform_tags = local.freeform_tags
}

{%- endif %}  

{%- if group_name is not defined %}
// XXXX to remove
locals {
    db_host = "none"
    db_url = "none"
    jdbc_url = "none"
}
{%- endif %}  
