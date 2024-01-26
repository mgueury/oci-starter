package com.example.fn;

import com.fnproject.fn.api.RuntimeContext;
import java.sql.*;
{%- if db_family == "oracle" %}
import oracle.ucp.jdbc.PoolDataSource;
import oracle.ucp.jdbc.PoolDataSourceFactory;
{%- endif %}	

public class HelloFunction {

	{%- if db_family != "none" %}
  private final String dbUser = System.getenv().get("DB_USER");
  private final String dbPassword = System.getenv().get("DB_PASSWORD");
  private final String dbUrl = System.getenv().get("DB_URL");
  {%- endif %}	

  {%- if db_family == "oracle" %}
  final static String CONN_FACTORY_CLASS_NAME = "oracle.jdbc.pool.OracleDataSource";
  private PoolDataSource poolDataSource;

  public HelloFunction() {
    System.out.println("Setting up pool data source");
    poolDataSource = PoolDataSourceFactory.getPoolDataSource();
    try {
      poolDataSource.setConnectionFactoryClassName(CONN_FACTORY_CLASS_NAME);
      poolDataSource.setURL(dbUrl);
      poolDataSource.setUser(dbUser);
      poolDataSource.setPassword(dbPassword);
      poolDataSource.setConnectionPoolName("UCP_POOL");
    } catch (SQLException e) {
      System.out.println("Pool data source error!");
      e.printStackTrace();
    }
    System.out.println("Pool data source setup...");
    System.setProperty("oracle.jdbc.fanEnabled", "false");
  }
  {%- else %}
  public HelloFunction() {}
  {%- endif %}	

  public String handleRequest(String input) {
    {%- if db_family == "none" %}
		return """
 		[ 
			{ "deptno": "10", "dname": "ACCOUNTING", "loc": "Seoul"},
			{ "deptno": "20", "dname": "RESEARCH", "loc": "Cape Town"},
			{ "deptno": "30", "dname": "SALES", "loc": "Brussels"},
			{ "deptno": "40", "dname": "OPERATIONS", "loc": "San Francisco"}
		] 
		""";
    {%- else %}
    // System.out.println("dbUser=" + dbUser + " / dbPassword=" + dbPassword + " / dbUurl=" + dbUrl);
    int counter = 0;
    StringBuffer sb = new StringBuffer();
    sb.append("[");
    try {
      System.out.println("Before classForName");
      Class.forName("{{ jdbcDriverClassName  }}");
      {%- if db_family == "oracle" %}
      Connection conn = poolDataSource.getConnection();
      {%- else %}
      Connection conn = DriverManager.getConnection(dbUrl, dbUser, dbPassword);
      {%- endif %}	
      System.out.println("After connection");
      Statement stmt = conn.createStatement();
      ResultSet rs = stmt.executeQuery("SELECT deptno, dname, loc FROM dept");
      while (rs.next()) {
        if (counter++ > 0) {
          sb.append(",");
        }
        sb.append("{\"deptno\": \"" + rs.getInt(1) + "\", \"dname\": \"" + rs.getString(2) + "\", \"loc\": \""
            + rs.getString(3) + "\"}");
      }
      stmt.close();
      conn.close();
    } catch (Exception e) {
      System.err.println("Exception:" + e.getMessage());
      e.printStackTrace();
    }
    sb.append("]");
    return sb.toString();
    {%- endif %}	
  }
}
