<xsl:stylesheet 
    version="1.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
    xmlns:sitemap="http://www.sitemaps.org/schemas/sitemap/0.9"
>
  <xsl:output method="html" indent="yes" encoding="UTF-8"/>
  <xsl:template match="/">
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1"/>
        <meta name="referrer" content="unsafe-url" />
        <title>sitemap.xml</title>
        <link rel="shortcut icon" href="/favicon.png" />
        <link rel="stylesheet" href="/main.css" type="text/css" />
      </head>
      <body>
        <main>
          <section class="posts">
            <b>Sitemap:</b>
            <hr />
            <ul>
            <xsl:apply-templates select="sitemap:urlset/sitemap:url" />
            </ul>
            <hr />
            <li><small><a href="/">[ Go back ]</a></small></li>
          </section>
        </main>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="sitemap:url">
    <li>
        <a target="_blank"><xsl:attribute name="href"><xsl:value-of select="sitemap:loc"/></xsl:attribute><xsl:value-of select="sitemap:loc"/></a>
    </li>
  </xsl:template>

</xsl:stylesheet>
