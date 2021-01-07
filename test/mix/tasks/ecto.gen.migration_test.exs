defmodule Mix.Tasks.Ecto.Gen.MigrationTest do
  use ExUnit.Case, async: true

  import Support.FileHelpers
  import Mix.Tasks.Ecto.Gen.Migration, only: [run: 1]

  tmp_path = Path.join(tmp_path(), inspect(Ecto.Gen.Migration))
  @migrations_path Path.join(tmp_path, "migrations")

  defmodule Repo do
    def __adapter__ do
      true
    end

    def config do
      [priv: "tmp/#{inspect(Ecto.Gen.Migration)}", otp_app: :ecto_sql]
    end
  end

  setup do
    File.rm_rf!(unquote(tmp_path))
    :ok
  end

  test "generates a new migration" do
    [path] = run ["-r", to_string(Repo), "my_migration"]
    assert Path.dirname(path) == @migrations_path
    assert Path.basename(path) =~ ~r/^\d{14}_my_migration\.exs$/
    assert_file path, fn file ->
      assert file =~ "defmodule Mix.Tasks.Ecto.Gen.MigrationTest.Repo.Migrations.MyMigration do"
      assert file =~ "use Ecto.Migration"
      assert file =~ "def change do"
    end
  end

  test "generates a new migration with Custom Migration Module" do
    Application.put_env(:ecto_sql, :migration_module, MyCustomApp.MigrationModule)
    [path] = run ["-r", to_string(Repo), "my_custom_migration"]
    Application.delete_env(:ecto_sql, :migration_module)
    assert Path.dirname(path) == @migrations_path
    assert Path.basename(path) =~ ~r/^\d{14}_my_custom_migration\.exs$/
    assert_file path, fn file ->
      assert file =~ "defmodule Mix.Tasks.Ecto.Gen.MigrationTest.Repo.Migrations.MyCustomMigration do"
      assert file =~ "use MyCustomApp.MigrationModule"
      assert file =~ "def change do"
    end
  end

  test "underscores the filename when generating a migration" do
    run ["-r", to_string(Repo), "MyMigration"]
    assert [name] = File.ls!(@migrations_path)
    assert name =~ ~r/^\d{14}_my_migration\.exs$/
  end

  test "custom migrations_path" do
    dir = Path.join([unquote(tmp_path), "custom_migrations"])
    [path] = run ["-r", to_string(Repo), "--migrations-path", dir, "custom_path"]
    assert Path.dirname(path) == dir
  end

  test "raises when existing migration exists" do
    run ["-r", to_string(Repo), "my_migration"]
    assert_raise Mix.Error, ~r"migration can't be created", fn ->
      run ["-r", to_string(Repo), "my_migration"]
    end
  end

  test "raises when missing file" do
    assert_raise Mix.Error, fn -> run ["-r", to_string(Repo)] end
  end

  test "generates migration within umbrella app without raising" do
    # Turn the project into an umbrella app
    project = Mix.ProjectStack.pop()
    umbrella_project_config = Keyword.put(project.config, :apps_path, "apps/")
    assert :ok == Mix.ProjectStack.push(project.name, umbrella_project_config, project.file)

    # Turn the project back into the original app config once the test ends
    on_exit(fn ->
      Mix.ProjectStack.pop()
      assert :ok == Mix.ProjectStack.push(project.name, project.config, project.file)
    end)

    assert Mix.Project.umbrella?()
    [path] = run ["-r", to_string(Repo), "my_migration"]
    assert Path.dirname(path) == @migrations_path
    assert Path.basename(path) =~ ~r/^\d{14}_my_migration\.exs$/
    assert_file path, fn file ->
      assert file =~ "defmodule Mix.Tasks.Ecto.Gen.MigrationTest.Repo.Migrations.MyMigration do"
      assert file =~ "use Ecto.Migration"
      assert file =~ "def change do"
    end
  end
end
