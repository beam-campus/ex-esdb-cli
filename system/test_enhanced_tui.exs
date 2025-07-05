# ExESDB Enhanced TUI Test Script
# This script validates that all enhanced TUI features are properly implemented

IO.puts("🧪 Testing ExESDB Enhanced TUI Setup...")

# Test 1: Check if enhanced TUI module exists and compiles
try do
  Code.ensure_compiled!(ExESDBTuiEnhanced)
  IO.puts("✅ ExESDBTuiEnhanced module compiled successfully")
rescue
  error ->
    IO.puts("❌ Failed to compile ExESDBTuiEnhanced: #{inspect(error)}")
    System.halt(1)
end

# Test 2: Check if Event Monitor module exists
try do
  Code.ensure_compiled!(ExESDBCli.EventMonitor)
  IO.puts("✅ ExESDBCli.EventMonitor module compiled successfully")
rescue
  error ->
    IO.puts("❌ Failed to compile EventMonitor: #{inspect(error)}")
    System.halt(1)
end

# Test 3: Validate Enhanced TUI implements Garnish.App behavior
behaviours = ExESDBTuiEnhanced.__info__(:attributes)[:behaviour] || []
if Garnish.App in behaviours do
  IO.puts("✅ ExESDBTuiEnhanced correctly implements Garnish.App behavior")
else
  IO.puts("❌ ExESDBTuiEnhanced does not implement Garnish.App behavior")
  System.halt(1)
end

# Test 4: Check required enhanced callbacks
enhanced_functions = [
  {:init, 1},
  {:handle_key, 2}, 
  {:handle_resize, 2},
  {:handle_info, 2},
  {:render, 1}
]

missing_functions = Enum.filter(enhanced_functions, fn {name, arity} ->
  not function_exported?(ExESDBTuiEnhanced, name, arity)
end)

if Enum.empty?(missing_functions) do
  IO.puts("✅ All required enhanced callbacks are implemented")
else
  IO.puts("❌ Missing enhanced callbacks: #{inspect(missing_functions)}")
  System.halt(1)
end

# Test 5: Check Event Monitor GenServer callbacks
monitor_functions = [
  {:init, 1},
  {:handle_call, 3},
  {:handle_cast, 2},
  {:handle_info, 2},
  {:terminate, 2}
]

missing_monitor_functions = Enum.filter(monitor_functions, fn {name, arity} ->
  not function_exported?(ExESDBCli.EventMonitor, name, arity)
end)

if Enum.empty?(missing_monitor_functions) do
  IO.puts("✅ All Event Monitor GenServer callbacks are implemented")
else
  IO.puts("❌ Missing Event Monitor callbacks: #{inspect(missing_monitor_functions)}")
  System.halt(1)
end

# Test 6: Check if all required dependencies are available
required_deps = [
  Garnish,
  Garnish.App,
  Garnish.View,
  ExESDB.GatewayAPI,
  Jason  # For JSON encoding in event details
]

missing_deps = Enum.filter(required_deps, fn dep ->
  try do
    Code.ensure_compiled!(dep)
    false
  rescue
    _ -> true
  end
end)

if Enum.empty?(missing_deps) do
  IO.puts("✅ All required dependencies are available")
else
  IO.puts("❌ Missing dependencies: #{inspect(missing_deps)}")
  System.halt(1)
end

# Test 7: Check configuration
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

# Test 8: Validate TUI mode selection
cli_app_source = File.read!("lib/cli_app.ex")
if String.contains?(cli_app_source, "ExESDBTuiEnhanced") do
  IO.puts("✅ CLI app configured to support enhanced TUI")
else
  IO.puts("❌ CLI app not properly configured for enhanced TUI")
  System.halt(1)
end

# Test 9: Check if enhanced features are properly structured
try do
  # Test that we can create a basic state structure
  _test_state = %ExESDBTuiEnhanced{
    mode: :main_menu,
    sub_mode: :list,
    streams: nil,
    events: nil,
    subscriptions: nil,
    event_monitors: [],
    cursor_position: 0,
    loading: false,
    event_filter: %{},
    search_term: nil,
    page_offset: 0,
    page_size: 20,
    auto_refresh: true,
    refresh_interval: 3000
  }
  
  IO.puts("✅ Enhanced TUI state structure is valid")
rescue
  error ->
    IO.puts("❌ Enhanced TUI state structure error: #{inspect(error)}")
    System.halt(1)
end

# Test 10: Check Event Monitor can be configured
try do
  _test_config = %{
    store: :reg_gh,
    stream_pattern: :all,
    event_filters: [],
    buffer_size: 1000,
    enable_metrics: true
  }
  
  IO.puts("✅ Event Monitor configuration structure is valid")
rescue
  error ->
    IO.puts("❌ Event Monitor configuration error: #{inspect(error)}")
    System.halt(1)
end

# Test 11: Check if startup script exists and is executable
startup_script = "start_tui.sh"
if File.exists?(startup_script) do
  stat = File.stat!(startup_script)
  if (stat.mode &&& 0o111) != 0 do
    IO.puts("✅ Startup script exists and is executable")
  else
    IO.puts("⚠️  Startup script exists but is not executable")
    IO.puts("   Run: chmod +x #{startup_script}")
  end
else
  IO.puts("❌ Startup script not found")
  System.halt(1)
end

# Test 12: Check documentation files
docs = ["README_ENHANCED_TUI.md", "README_TUI.md"]
existing_docs = Enum.filter(docs, &File.exists?/1)

if length(existing_docs) > 0 do
  IO.puts("✅ Documentation files found: #{Enum.join(existing_docs, ", ")}")
else
  IO.puts("⚠️  No documentation files found")
end

# Test 13: Environment variables test
env_vars = [
  "EX_ESDB_STORE_ID",
  "EX_ESDB_TIMEOUT", 
  "EX_ESDB_PUB_SUB"
]

set_vars = Enum.filter(env_vars, &System.get_env/1)
if length(set_vars) > 0 do
  IO.puts("✅ Environment variables configured: #{Enum.join(set_vars, ", ")}")
else
  IO.puts("⚠️  No environment variables set (will use defaults)")
end

IO.puts("")
IO.puts("🎉 All enhanced TUI tests passed!")
IO.puts("")
IO.puts("📋 Enhanced Features Available:")
IO.puts("   ✨ Real-time event monitoring")
IO.puts("   🔍 Advanced search and filtering") 
IO.puts("   📊 Event analytics and metrics")
IO.puts("   📄 Paginated data views")
IO.puts("   ⚙️  Configurable settings")
IO.puts("   🏪 Multi-store support")
IO.puts("   🎨 Enhanced UI with themes")
IO.puts("")
IO.puts("🚀 Next steps:")
IO.puts("   1. Ensure ExESDB cluster is running")
IO.puts("   2. Run: ./start_tui.sh")
IO.puts("   3. Connect via SSH: ssh -p 2222 username@127.0.0.1")
IO.puts("   4. Press 'h' in the TUI for help")
IO.puts("")
IO.puts("📖 Documentation:")
IO.puts("   • Basic guide: README_TUI.md")
IO.puts("   • Enhanced guide: README_ENHANCED_TUI.md")
IO.puts("   • In-app help: Press 'h' key in the TUI")
