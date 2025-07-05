# ExESDB TUI Setup Test Script
# This script validates that the TUI application can be compiled and dependencies are correct

IO.puts("🧪 Testing ExESDB TUI Setup...")

# Test 1: Check if ExESDBTuiApp module exists and compiles
try do
  Code.ensure_compiled!(ExESDBTuiApp)
  IO.puts("✅ ExESDBTuiApp module compiled successfully")
rescue
  error ->
    IO.puts("❌ Failed to compile ExESDBTuiApp: #{inspect(error)}")
    System.halt(1)
end

# Test 2: Check if Garnish is available
try do
  Code.ensure_compiled!(Garnish)
  Code.ensure_compiled!(Garnish.App)
  Code.ensure_compiled!(Garnish.View)
  IO.puts("✅ Garnish library is available")
rescue
  error ->
    IO.puts("❌ Garnish library not available: #{inspect(error)}")
    System.halt(1)
end

# Test 3: Check if ExESDB.GatewayAPI is available
try do
  Code.ensure_compiled!(ExESDB.GatewayAPI)
  IO.puts("✅ ExESDB.GatewayAPI is available")
rescue
  error ->
    IO.puts("❌ ExESDB.GatewayAPI not available: #{inspect(error)}")
    System.halt(1)
end

# Test 4: Validate that ExESDBTuiApp implements Garnish.App behavior
behaviours = ExESDBTuiApp.__info__(:attributes)[:behaviour] || []
if Garnish.App in behaviours do
  IO.puts("✅ ExESDBTuiApp correctly implements Garnish.App behavior")
else
  IO.puts("❌ ExESDBTuiApp does not implement Garnish.App behavior")
  System.halt(1)
end

# Test 5: Check required callbacks
required_functions = [
  {:init, 1},
  {:handle_key, 2}, 
  {:render, 1}
]

missing_functions = Enum.filter(required_functions, fn {name, arity} ->
  not function_exported?(ExESDBTuiApp, name, arity)
end)

if Enum.empty?(missing_functions) do
  IO.puts("✅ All required Garnish.App callbacks are implemented")
else
  IO.puts("❌ Missing required callbacks: #{inspect(missing_functions)}")
  System.halt(1)
end

# Test 6: Check configuration
try do
  opts = ExESDBCli.Options.app_env()
  store_id = ExESDBCli.Options.store_id()
  timeout = ExESDBCli.Options.timeout()
  pub_sub = ExESDBCli.Options.pub_sub()
  
  IO.puts("✅ Configuration loaded successfully:")
  IO.puts("   • Store ID: #{inspect(store_id)}")
  IO.puts("   • Timeout: #{timeout}ms")
  IO.puts("   • Pub/Sub: #{inspect(pub_sub)}")
rescue
  error ->
    IO.puts("❌ Configuration error: #{inspect(error)}")
    System.halt(1)
end

IO.puts("")
IO.puts("🎉 All tests passed! ExESDB TUI is ready to run.")
IO.puts("📋 Next steps:")
IO.puts("   1. Ensure ExESDB cluster is running")
IO.puts("   2. Run: ./start_tui.sh")
IO.puts("   3. Connect via SSH: ssh -p 2222 username@127.0.0.1")
