/**
 * The ColdBox Async Manager is in charge of creating runnable proxies based on
 * components or closures that can be spawned as native Java Completable future
 * to support you with multi-threaded and asynchronous programming.
 *
 * The manager can also help you create executor services so you can define your own
 * thread pools according to your needs.  If not, the majority of the asynchronous
 * methods will use the ForkJoin.commonPool() implementation
 */
component accessors="true" singleton {

	/**
	 * A collection of executors you can register in the async manager
	 * so you can run queues, tasks or even scheduled tasks
	 */
	property name="executors" type="struct";

	// Static class to Executors: java.util.concurrent.Executors
	this.$executors = new util.Executors();

	/**
	 * Constructor
	 *
	 * @debug Add debugging logs to System out, disabled by default
	 */
	AsyncManager function init( boolean debug = false ){
		variables.debug     = arguments.debug;
		variables.executors = {};

		return this;
	}

	/****************************************************************
	 * Executor Methods *
	 ****************************************************************/

	/**
	 * Creates and registers an Executor according to the passed name, type and options.
	 * The allowed types are: fixed, cached, single, scheduled with fixed being the default.
	 *
	 * You can then use this executor object to submit tasks for execution and if it's a
	 * scheduled executor then actually execute scheduled tasks.
	 *
	 * Types of Executors:
	 * - fixed : By default it will build one with 20 threads on it. Great for multiple task execution and worker processing
	 * - single : A great way to control that submitted tasks will execute in the order of submission: FIFO
	 * - cached : An unbounded pool where the number of threads will grow according to the tasks it needs to service. The threads are killed by a default 60 second timeout if not used and the pool shrinks back
	 * - scheduled : A pool to use for scheduled tasks that can run one time or periodically
	 *
	 * @see https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/ExecutorService.html
	 *
	 * @name The name of the executor used for registration
	 * @type The type of executor to build fixed, cached, single, scheduled
	 * @threads How many threads to assign to the thread scheduler, default is 20
	 * @debug Add output debugging
	 * @loadAppContext Load the CFML App contexts or not, disable if not used
	 *
	 * @return The ColdBox Schedule class to work with the schedule: coldbox.system.async.tasks.Executor
	 */
	Executor function newExecutor(
		required name,
		type                   = "fixed",
		numeric threads        = this.$executors.DEFAULT_THREADS,
		boolean debug          = false,
		boolean loadAppContext = true
	){
		// Build it if not found
		if ( !variables.executors.keyExists( arguments.name ) ) {
			// Create the ColdBox executor and register it
			variables.executors[ arguments.name ] = buildExecutor( argumentCollection = arguments );
		}

		// Return it
		return variables.executors[ arguments.name ];
	}

	/**
	 * Build a Java executor according to passed type and threads
	 * @see https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/Executors.html
	 *
	 * @type Available types are: fixed, cached, single, scheduled
	 * @threads The number of threads to seed the executor with, if it allows it
	 * @debug Add output debugging
	 * @loadAppContext Load the CFML App contexts or not, disable if not used
	 *
	 * @return A Java ExecutorService: https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/ExecutorService.html
	 */
	private function buildExecutor(
		required type,
		numeric threads,
		boolean debug          = false,
		boolean loadAppContext = true
	){
		// Factory to build the right executor
		switch ( arguments.type ) {
			case "fixed": {
				arguments.executor = this.$executors.newFixedThreadPool( arguments.threads );
				return new tasks.Executor( argumentCollection = arguments );
			}
			case "cached": {
				arguments.executor = this.$executors.newCachedThreadPool();
				return new tasks.Executor( argumentCollection = arguments );
			}
			case "single": {
				arguments.executor = this.$executors.newFixedThreadPool( 1 );
				return new tasks.Executor( argumentCollection = arguments );
			}
			case "scheduled": {
				arguments.executor = this.$executors.newScheduledThreadPool( arguments.threads );
				return new tasks.ScheduledExecutor( argumentCollection = arguments );
			}
		}
		throw(
			type    = "InvalidExecutorType",
			message = "The executor you requested :#arguments.type# does not exist.",
			detail  = "Valid executors are: fixed, cached, single, scheduled"
		);
	}

	/**
	 * Shortcut to newExecutor( type: "scheduled" )
	 */
	Executor function newScheduledExecutor(
		required name,
		numeric threads        = this.$executors.DEFAULT_THREADS,
		boolean debug          = false,
		boolean loadAppContext = true
	){
		arguments.type = "scheduled";
		return newExecutor( argumentCollection = arguments );
	}

	/**
	 * Shortcut to newExecutor( type: "single", threads: 1 )
	 */
	Executor function newSingleExecutor(
		required name,
		boolean debug          = false,
		boolean loadAppContext = true
	){
		arguments.type = "single";
		return newExecutor( argumentCollection = arguments );
	}

	/**
	 * Shortcut to newExecutor( type: "cached" )
	 */
	Executor function newCachedExecutor(
		required name,
		numeric threads        = this.$executors.DEFAULT_THREADS,
		boolean debug          = false,
		boolean loadAppContext = true
	){
		arguments.type = "cached";
		return newExecutor( argumentCollection = arguments );
	}

	/**
	 * Get a registered executor registerd in this async manager
	 *
	 * @name The executor name
	 *
	 * @throws ExecutorNotFoundException
	 * @return The executor object: coldbox.system.async.tasks.Executor
	 */
	Executor function getExecutor( required name ){
		if ( hasExecutor( arguments.name ) ) {
			return variables.executors[ arguments.name ];
		}
		throw(
			type    = "ExecutorNotFoundException",
			message = "The schedule you requested does not exist",
			detail  = "Registered schedules are: #variables.executors.keyList()#"
		);
	}

	/**
	 * Get the array of registered executors in the system
	 *
	 * @return Array of names
	 */
	array function getExecutorNames(){
		return variables.executors.keyArray();
	}

	/**
	 * Verify if an executor exists
	 *
	 * @name The executor name
	 */
	boolean function hasExecutor( required name ){
		return variables.executors.keyExists( arguments.name );
	}

	/**
	 * Delete an executor from the registry, if the executor has not shutdown, it will shutdown the executor for you
	 * using the shutdownNow() event
	 *
	 * @name The scheduler name
	 */
	AsyncManager function deleteExecutor( required name ){
		if ( hasExecutor( arguments.name ) ) {
			if ( !variables.executors[ arguments.name ].isShutdown() ) {
				variables.executors[ arguments.name ].shutdownNow();
			}
			variables.executors.delete( arguments.name );
		}
		return this;
	}

	/**
	 * Shutdown an executor or force it to shutdown, you can also do this from the Executor themselves.
	 * If an un-registered executor name is passed, it will ignore it
	 *
	 * @force Use the shutdownNow() instead of the shutdown() method
	 */
	AsyncManager function shutdownExecutor( required name, boolean force = false ){
		if ( hasExecutor( arguments.name ) ) {
			if ( arguments.force ) {
				variables.executors[ arguments.name ].shutdownNow();
			} else {
				variables.executors[ arguments.name ].shutdown();
			}
		}
		return this;
	}

	/**
	 * Shutdown all registered executors in the system
	 *
	 * @force By default (false) it gracefullly shuts them down, else uses the shutdownNow() methods
	 *
	 * @return AsyncManager
	 */
	AsyncManager function shutdownAllSchedules( boolean force = false ){
		variables.executors.each( function( key, schedule ){
			if ( force ) {
				arguments.schedule.shutdownNow();
			} else {
				arguments.schedule.shutdown();
			}
		} );
		return this;
	}

	/**
	 * Returns a structure of status maps for every registered executor in the
	 * manager. This is composed of tons of stats about the executor
	 *
	 * @name The name of the executor to retrieve th status map ONLY!
	 *
	 * @return A struct of metadata about the executor or all executors
	 */
	struct function getExecutorStatusMap( name ){
		if ( !isNull( arguments.name ) ) {
			return getExecutor( arguments.name ).getStats();
		}

		return variables.executors.map( function( key, thisExecutor ){
			return arguments.thisExecutor.getStats();
		} );
	}

	/****************************************************************
	 * Future Creation Methods *
	 ****************************************************************/

	/**
	 * Create a new ColdBox future backed by a Java completable future
	 *
	 * @value The actual closure/lambda/udf to run with or a completed value to seed the future with
	 * @executor A custom executor to use with the future, else use the default
	 * @debug Add debugging to system out or not, defaults is false
	 * @loadAppContext Load the CFML engine context into the async threads or not, default is yes.
	 *
	 * @return ColdBox Future completed or new
	 */
	Future function newFuture(
		any value,
		any executor,
		boolean debug          = false,
		boolean loadAppContext = true
	){
		return new Future( argumentCollection = arguments );
	}

	/**
	 * Create a completed ColdBox future backed by a Java Completable Future
	 *
	 * @value The value to complete the future with
	 * @debug Add debugging to system out or not, defaults is false
	 * @loadAppContext Load the CFML engine context into the async threads or not, default is yes.
	 *
	 * @return ColdBox Future completed
	 */
	Future function newCompletedFuture(
		required any value,
		boolean debug          = false,
		boolean loadAppContext = true
	){
		return new Future( argumentCollection = arguments );
	}

	/****************************************************************
	 * Future Creation Shortcuts *
	 ****************************************************************/

	/**
	 * Alias to newFuture().allOf()
	 */
	function allOf(){
		return newFuture().allOf( argumentCollection = arguments );
	}

	/**
	 * Alias to newFuture().allApply()
	 */
	function allApply(){
		return newFuture().allApply( argumentCollection = arguments );
	}

	/**
	 * Alias to newFuture().anyOf()
	 */
	function anyOf(){
		return newFuture().anyOf( argumentCollection = arguments );
	}

}