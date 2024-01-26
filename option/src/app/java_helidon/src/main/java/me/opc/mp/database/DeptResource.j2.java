{% import "java.j2_macro" as m with context %}
package me.opc.mp.database;

import java.util.*;
import java.util.stream.*;
import java.io.*;
import java.net.*;
import javax.json.*;

import jakarta.persistence.*;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

/**
 * Dept Table 
 */
@Path("/")
public class DeptResource {
    {%- if db_family != "none" and db_family != "opensearch" %}
    @PersistenceContext(unitName = "pu1")
    private EntityManager entityManager;
    {%- endif %}	

    @GET
    @Path("dept")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Dept> getDept() throws Exception {
        {%- if db_family == "none" %}
        {{ m.nodb() }}
        {%- elif db_family == "opensearch" %}
        {{ m.opensearch() }}
        {%- else %}
        return entityManager.createNamedQuery("getDept", Dept.class).getResultList();
        {%- endif %}	
    }

    @GET
    @Path("info")
    @Produces(MediaType.TEXT_PLAIN)
    public String getInfo() {
        return "Java - Helidon / {{ dbName }}";
    }
}