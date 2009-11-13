<!-----------------------------------------------------------------------
********************************************************************************
Copyright 2005-2008 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldboxframework.com | www.luismajano.com | www.ortussolutions.com
********************************************************************************

Author     :	Luis Majano
Date        :	3/13/2009
Description :
	This is a LogBox configuration object.  You can use it to configure
	a log box instance.
----------------------------------------------------------------------->
<cfcomponent name="LogBoxConfig" output="false" hint="This is a LogBox configuration object.  You can use it to configure a log box instance">

	<cfscript>
		// The log levels enum as a public property
		this.logLevels = createObject("component","coldbox.system.logging.LogLevels");
		
		// Instance private scope
		instance = structnew();
		
		// Startup the configuration
		reset();
	</cfscript>

	<!--- init --->
	<cffunction name="init" output="false" access="public" returntype="LogBoxConfig" hint="Constructor">
		<cfargument name="xmlConfig" type="string" required="false" default="" hint="The xml configuration file to use instead of a programmatic approach"/>
		<cfscript>
			if( len(trim(arguments.xmlConfig)) ){
				parseAndLoad(xmlParse(arguments.xmlConfig));
			}
			
			return this;
		</cfscript>
	</cffunction>
	
	<!--- reset --->
	<cffunction name="reset" output="false" access="public" returntype="void" hint="Reset the configuration">
		<cfscript>
			// Register appenders
			instance.appenders = structnew();
			// Register categories
			instance.categories = structnew();
			// Register root logger
			instance.rootLogger = structnew();
		</cfscript>
	</cffunction>
	
	<!--- Get Memento --->
	<cffunction name="getMemento" access="public" returntype="struct" output="false" hint="Get the instance data">
		<cfreturn instance>
	</cffunction>

	
	<!--- validate --->
	<cffunction name="validate" output="false" access="public" returntype="void" hint="Validates the configuration. If not valid, it will throw an appropriate exception.">
		<cfscript>
			var x=1;
			var key ="";
			var thisAppenders = "";
			
			// Are appenders defined
			if( structIsEmpty(instance.appenders) ){
				$throw(message="Invalid Configuration. No appenders defined.",type="LogBoxConfig.NoAppendersFound");
			}
			// Check root logger definition
			if( structIsEmpty(instance.rootLogger) ){
				$throw(message="Invalid Configuration. No root logger defined.",type="LogBoxConfig.RootLoggerNotFound");
			}
			
			// All root appenders?
			if( instance.rootLogger.appenders eq "*"){
				instance.rootLogger.appenders = structKeyList(getAllAppenders());
			}
			// Check root's appenders
			for(x=1; x lte listlen(instance.rootLogger.appenders); x=x+1){
				if( NOT structKeyExists(instance.appenders, listGetAt(instance.rootLogger.appenders,x)) ){
					$throw(message="Invalid appender in Root Logger",
						   detail="The appender #listGetAt(instance.rootLogger.appenders,x)# has not been defined yet. Please define it first.",
						   type="LogBoxConfig.AppenderNotFound");
				}
			}
			
			// Check all Category Appenders
			for(key in instance.categories){
				thisAppenders = instance.categories[key].appenders;
				
				// Check * all appenders
				if( thisAppenders eq "*"){
					instance.categories[key].appenders = structKeyList(getAllAppenders());
					continue;
				}
				
				for(x=1; x lte listlen(thisAppenders); x=x+1){
					if( NOT structKeyExists(instance.appenders, listGetAt(thisAppenders,x)) ){
						$throw(message="Invalid appender in Category: #key#",
							   detail="The appender #listGetAt(thisAppenders,x)# has not been defined yet. Please define it first.",
							   type="LogBoxConfig.AppenderNotFound");
					}
				}
			}
		</cfscript>
	</cffunction>
	
	<!--- addAppender --->
	<cffunction name="appender" output="false" access="public" returntype="void" hint="Add an appender configuration.">
		<cfargument name="name" 		type="string"  required="true"  hint="A unique name for the appender to register. Only unique names can be registered per instance."/>
		<cfargument name="class" 		type="string"  required="true"  hint="The appender's class to register. We will create, init it and register it for you."/>
		<cfargument name="properties" 	type="struct"  required="false" default="#structnew()#" hint="The structure of properties to configure this appender with."/>
		<cfargument name="layout" 		type="string"  required="true"  default="" hint="The layout class path to use in this appender for custom message rendering."/>
		<cfscript>
			// REgister appender
			instance.appenders[arguments.name] = arguments;
		</cfscript>
	</cffunction>
	
	<!--- Set the root logger information  --->
	<cffunction name="root" access="public" returntype="void" output="false" hint="Register the root logger in this configuration.">
		<cfargument name="levelMin" 	type="numeric" required="false" default="0" hint="The default log level for the root logger, by default it is 0 (FATAL). Optional. ex: config.logLevels.WARN"/>
		<cfargument name="levelMax" 	type="numeric" required="false" default="4" hint="The default log level for the root logger, by default it is 4 (DEBUG). Optional. ex: config.logLevels.WARN"/>
		<cfargument name="appenders" 	type="string"  required="true"  hint="A list of appenders to configure the root logger with. Send a * to add all appenders"/>
		<cfscript>
			var x = 1;
			
			// Check levels
			levelChecks(arguments.levelMin, arguments.levelMax);
			
			//Verify appender list
			if( NOT listLen(arguments.appenders) ){
				$throw("Invalid Appenders","Please send in at least one appender for the root logger","LogBoxConfig.InvalidAppenders");
			}

			// Add definition
			instance.rootLogger = arguments;
		</cfscript>
	</cffunction>
	
	<!--- Get root logger --->
	<cffunction name="getRoot" access="public" returntype="struct" output="false" hint="Get the root logger definition.">
		<cfreturn instance.rootLogger>
	</cffunction>
	
	<!--- addCategory --->
	<cffunction name="category" output="false" access="public" returntype="void" hint="Add a new category configuration with appender(s).  Appenders MUST be defined first, else this method will throw an exception">
		<cfargument name="name" 		type="string"  required="true"  hint="A unique name for the appender to register. Only unique names can be registered per instance."/>
		<cfargument name="levelMin" 	type="numeric" required="false" default="0" hint="The default min log level for this category. Defaults to the lowest level 0 or FATAL"/>
		<cfargument name="levelMax" 	type="numeric" required="false" default="4" hint="The max default log level for this category. If not passed it defaults to the highest level possible"/>
		<cfargument name="appenders" 	type="string"  required="false" default=""  hint="A list of appender names to configure this category with."/>
		<cfscript>
			var x = 1;
			
			// Check levels
			levelChecks(arguments.levelMin, arguments.levelMax);

			// Add category registration
			instance.categories[arguments.name] = arguments;
		</cfscript>
	</cffunction>
	
	<!--- getCategory --->
	<cffunction name="getCategory" output="false" access="public" returntype="struct" hint="Get a specifed category definition">
		<cfargument name="name" type="string" required="true" hint="The category to retrieve"/>
		<cfreturn instance.categories[arguments.name]>
	</cffunction>
	
	<!--- categoryExists --->
	<cffunction name="categoryExists" output="false" access="public" returntype="boolean" hint="Check if a category definition exists">
		<cfargument name="name" type="string" required="true" hint="The category to retrieve"/>
		<cfreturn structKeyExists(instance.categories, arguments.name)>
	</cffunction>
	
	<!--- getCategories --->
	<cffunction name="getAllCategories" output="false" access="public" returntype="struct" hint="Get the configured categories">
		<cfreturn instance.categories>
	</cffunction>
	
	<!--- getappenders --->
	<cffunction name="getAllAppenders" output="false" access="public" returntype="struct" hint="Get all the configured appenders">
		<cfreturn instance.appenders>
	</cffunction>
	
<!------------------------------------------- Facade methods for categoreis with levels only ------------------------------------------>
	
	<!--- DEBUG --->
	<cffunction name="DEBUG" output="false" access="public" returntype="void" hint="Add categories to the DEBUG level. Send each category as an argument.">
		<cfscript>
			var key = "";
			for(key in arguments){
				category(name=arguments[key],levelMin=this.logLevels.DEBUG,levelMax=this.logLevels.DEBUG);
			}
		</cfscript>
	</cffunction>
	
	<!--- INFO --->
	<cffunction name="INFO" output="false" access="public" returntype="void" hint="Add categories to the INFO level. Send each category as an argument.">
		<cfscript>
			var key = "";
			for(key in arguments){
				category(name=arguments[key],levelMin=this.logLevels.INFO,levelMax=this.logLevels.INFO);
			}
		</cfscript>
	</cffunction>
	
	<!--- WARN --->
	<cffunction name="WARN" output="false" access="public" returntype="void" hint="Add categories to the WARN level. Send each category as an argument.">
		<cfscript>
			var key = "";
			for(key in arguments){
				category(name=arguments[key],levelMin=this.logLevels.WARN,levelMax=this.logLevels.WARN);
			}
		</cfscript>
	</cffunction>
	
	<!--- ERROR --->
	<cffunction name="ERROR" output="false" access="public" returntype="void" hint="Add categories to the ERROR level. Send each category as an argument.">
		<cfscript>
			var key = "";
			for(key in arguments){
				category(name=arguments[key],levelMin=this.logLevels.ERROR,levelMax=this.logLevels.ERROR);
			}
		</cfscript>
	</cffunction>
	
	<!--- FATAL --->
	<cffunction name="FATAL" output="false" access="public" returntype="void" hint="Add categories to the FATAL level. Send each category as an argument.">
		<cfscript>
			var key = "";
			for(key in arguments){
				category(name=arguments[key],levelMin=this.logLevels.FATAL,levelMax=this.logLevels.FATAL);
			}
		</cfscript>
	</cffunction>
	
	<!--- OFF --->
	<cffunction name="OFF" output="false" access="public" returntype="void" hint="Add categories to the OFF level. Send each category as an argument.">
		<cfscript>
			var key = "";
			for(key in arguments){
				category(name=arguments[key],levelMin=this.logLevels.OFF,levelMax=this.logLevels.OFF);
			}
		</cfscript>
	</cffunction>

	<!--- parseAndLoad --->
	<cffunction name="parseAndLoad" output="false" access="public" returntype="void" hint="Parse and load a config xml object">
		<cfargument name="xmlDoc" type="any" required="true" hint="The xml document object to use for parsing."/>
		<cfscript>
			// Get All Appenders
			var xml = arguments.xmlDoc;
			var appendersXML = xmlSearch(xml,"//Appender");
			var rootXML = xmlSearch(xml,"//Root");
			var categoriesXML = xmlSearch(xml,"//Category");
			var args = structnew();
			var x =1;
			var y =1;
			
			//Register all appenders
			for(x=1; x lte arrayLen(appendersXML); x=x+1){
				args = structnew();
				args.properties = structnew();
				thisAppender = appendersXML[x];
				// Error
				if( NOT structKeyExists(thisAppender.XMLAttributes,"name") OR NOT 
				        structKeyExists(thisAppender.XMLAttributes,"class") ){
					$throw(message="An appender must have a name and class attribute",type="LogBoxConfig.InvalidAppenderDefinition");
				}
				// Construct appender Properties
				args.name = trim(thisAppender.XMLAttributes.name);
				args.class = trim(thisAppender.XMLAttributes.class);
				
				//Appender layout
				if( structKeyExists(thisAppender.XMLAttributes,"layout") ){
					args.layout = trim(thisAppender.XMLAttributes.layout);
				}
				// Check Properties Out
				for(y=1; y lte arrayLen(thisAppender.xmlChildren); y=y+1 ){
					args.properties[trim(thisAppender.xmlChildren[y].xmlAttributes.name)] = trim(thisAppender.xmlChildren[y].xmlText);
				}
				// Register appender
				appender(argumentCollection=args);
			}
			//Register Root Logger
			if( NOT arrayLen(rootXML) ){
				$throw(message="The root element cannot be found and it is mandatory",type="LogBoxConfig.RootLoggerNotFound");
			}
			args = structnew();
			if( structKeyExists(rootXML[1].xmlAttributes,"levelMin") ){
				args.levelMin = trim(rootXML[1].xmlAttributes.levelMin);
				// Numeric Check
				if( NOT isNumeric(args.levelMin) ){
					args.levelMin = this.logLevels.lookupAsInt(args.levelMin);
				}
			}
			if( structKeyExists(rootXML[1].xmlAttributes,"levelMax") ){
				args.levelMax = trim(rootXML[1].xmlAttributes.levelMax);
				// Numeric Check
				if( NOT isNumeric(args.levelMax) ){
					args.levelMax = this.logLevels.lookupAsInt(args.levelMax);
				}
			}
			
			//Root Appenders
			if( structKeyExists(rootXML[1].xmlAttributes,"appenders") ){
				args.appenders = trim(rootXML[1].xmlAttributes.appenders);
			}
			else{
				args.appenders = "";
				for( x=1; x lte arrayLen(rootXML[1].xmlChildren); x=x+1){
					if( rootXML[1].xmlChildren[x].XMLName eq "Appender-ref" ){
						args.appenders = listAppend(args.appenders, trim(rootXML[1].xmlChildren[x].XMLAttributes.ref) );
					}
				}
			}
			root(argumentCollection=args);
			
			//Categories
			for( x=1; x lte arrayLen(categoriesXML); x=x+1){
				args = structnew();
				
				// Category Name
				if( NOT structKeyExists(categoriesXML[x].XMLAttributes,"name") ){
					$throw(message="A category definition must have a name attribute",type="LogBoxConfig.InvalidCategoryDefinition");
				}
				args.name = trim(categoriesXML[x].XMLAttributes.name);
				
				// Level Min
				if( structKeyExists(categoriesXML[x].XMLAttributes,"levelMin") ){
					args.levelMin = trim(categoriesXML[x].XMLAttributes.levelMin);
					if( NOT isNumeric(args.levelMin) ){
						args.levelMin = this.logLevels.lookupAsInt(args.levelMin);
					}
				}
				
				// Level Max
				if( structKeyExists(categoriesXML[x].XMLAttributes,"levelMax") ){
					args.levelMax = trim(categoriesXML[x].XMLAttributes.levelMax);
					if( NOT isNumeric(args.levelMax) ){
						args.levelMax = this.logLevels.lookupAsInt(args.levelMax);
					}
				}
				
				//Category Appenders
				if( structKeyExists(categoriesXML[x].XMLAttributes,"appenders") ){
					args.appenders = trim(categoriesXML[x].XMLAttributes.appenders);
				}
				else{
					args.appenders = "";
					for( y=1; y lte arrayLen(categoriesXML[x].xmlChildren); y=y+1){
						if( categoriesXML[x].xmlChildren[y].XMLName eq "Appender-ref" ){
							args.appenders = listAppend(args.appenders, trim(categoriesXML[x].xmlChildren[y].XMLAttributes.ref) );
						}
					}
				}
				// Register category
				category(argumentCollection=args);
			}
		</cfscript>
	</cffunction>
	
<!------------------------------------------- PRIVATE ------------------------------------------>

	

	<!--- levelChecks --->
	<cffunction name="levelChecks" output="false" access="private" returntype="void" hint="Level checks or throw">
		<cfargument name="levelMin" 	type="numeric" required="true"/>
		<cfargument name="levelMax" 	type="numeric" required="true"/>
		<cfif NOT this.logLevels.isLevelValid(arguments.levelMin)>
			<cfthrow message="LevelMin #arguments.levelMin# is not a valid level." type="LogBoxConfig.InvalidLevel">
		<cfelseif NOT this.logLevels.isLevelValid(arguments.levelMax)>
			<cfthrow message="LevelMin #arguments.levelMax# is not a valid level." type="LogBoxConfig.InvalidLevel">
		</cfif>
	</cffunction>

	<!--- Throw Facade --->
	<cffunction name="$throw" access="private" hint="Facade for cfthrow" output="false">
		<!--- ************************************************************* --->
		<cfargument name="message" 	type="string" 	required="yes">
		<cfargument name="detail" 	type="string" 	required="no" default="">
		<cfargument name="type"  	type="string" 	required="no" default="Framework">
		<!--- ************************************************************* --->
		<cfthrow type="#arguments.type#" message="#arguments.message#"  detail="#arguments.detail#">
	</cffunction>
	
		<!--- Dump facade --->
	<cffunction name="$dump" access="private" hint="Facade for cfmx dump" returntype="void">
		<cfargument name="var" required="yes" type="any">
		<cfargument name="isAbort" type="boolean" default="false" required="false" hint="Abort also"/>
		<cfdump var="#var#">
		<cfif arguments.isAbort><cfabort></cfif>
	</cffunction>
	
	<!--- Abort Facade --->
	<cffunction name="$abort" access="private" hint="Facade for cfabort" returntype="void" output="false">
		<cfabort>
	</cffunction>
	
</cfcomponent>