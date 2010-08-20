#!/usr/bin/env ruby

require File.join(File.dirname(File.dirname(File.expand_path(__FILE__))),
                  'external/dist/share/service_testing/bp_service_runner.rb')
require 'uri'
require 'test/unit'
require 'open-uri'
require 'rbconfig'
include Config

class TestDirectory < Test::Unit::TestCase
  def setup
    subdir = 'build/Directory'
    if ENV.key?('BP_OUTPUT_DIR')
      subdir = ENV['BP_OUTPUT_DIR']
    end
    @cwd = File.dirname(File.expand_path(__FILE__))
    @service = File.join(@cwd, "../#{subdir}")
    @path1 = @cwd + "/test_files/"
    @path_testdir = @path1 + "test_directory/"
    @path_testdir_noP = @path1 + "test_directory"
    @path_testdir1 = @path1 + "test_directory/test_directory_1/"
    @test_directory = "path://" + @path1 + "test_directory/"
    @test_directory_1 = "path://" + @path1 + "test_directory/test_directory_1"
  end
  
  def teardown
  end

  def test_load_service
    BrowserPlus.run(@service) { |s|
    }
  end

  # BrowserPlus.Directory.list({params}, function{}())
  # Returns a list in "files" of filehandles resulting from a non-recursive traversal of the arguments. No directory structure information is returned.
  def test_list
    BrowserPlus.run(@service) { |s|
      # Directory/File does not exist, should return error <------------------------- BUG 212
      #list = Array.[]( @test_directory_1 + "/this" )
      #got = s.list( { 'files' => list  } ) { |callback| puts callback }
      #puts got

      # 3 text files.
      list = Array.[]( @test_directory_1 )
      want = { "files" => [@path_testdir1 + "bar1.txt", @path_testdir1 + "bar2.txt", @path_testdir1 + "bar3.txt"], "success" => true }
      got = s.list({ 'files' => list })
      assert_equal(want, got)

      # Just one folder, no symbolic links.
      list = Array.[]( @test_directory )
      want = {"files" =>
              [@path_testdir + "foo1.txt",
               @path_testdir + "foo2.txt",
               @path_testdir + "foo3.txt",
               @path_testdir + "sym_link",
               @path_testdir + "test_directory_1"],
             "success" => true}
      got = s.list({ 'files' => list, "followLinks" => false })
      assert_equal(want, got)

      # Symbolic links.
      list = Array.[]( @test_directory )
      want = {"files" =>
              [@path_testdir + "foo1.txt",
               @path_testdir + "foo2.txt",
               @path_testdir + "foo3.txt",
               if CONFIG['arch'] =~ /mswin|mingw/
                 @path_testdir + "sym_link"
               else
                 @path1 + "sym_link"
               end,
               @path_testdir + "test_directory_1"],
              "success" => true}
      got = s.list({ 'files' => list, "followLinks" => true })
      assert_equal(want, got)

      # Mimetype => text/plain.
      list = Array.[]( @test_directory )
      want = {"files" =>
              [@path_testdir + "foo1.txt",
               @path_testdir + "foo2.txt",
               @path_testdir + "foo3.txt"],
              "success" => true}
      got = s.list({ 'files' => list, "followLinks" => false, "mimetypes" => ["text/plain"] })
      assert_equal(want, got)

      # Mimetype => image/jpeg ---- none present.
      list = Array.[]( @test_directory )
      want = {"files" => [], "success" => true}
      got = s.list({ 'files' => list, "followLinks" => false, "mimetypes" => ["image/jpeg"] })
      assert_equal(want, got)

      # Size = 2.
      list = Array.[]( @test_directory )
      want = {"files" =>
              [@path_testdir + "foo1.txt",
               @path_testdir + "foo2.txt"],
              "success" => true}
      got = s.list({ 'files' => list, "followLinks" => true, "limit" => 2 })
      assert_equal(want, got)

      # Callback.
      x = 1
      list = Array.[]( @test_directory )
      got = s.list({ 'files' => list, "followLinks" => true, "limit" => 2 }, x = x + 1)
      assert_equal( 2, x )
    }
  end

  # BrowserPlus.Directory.recursiveList({params}, function{}())
  # Returns a list in "files" of filehandles resulting from a recursive traversal of the arguments. No directory structure information is returned
  def test_recursiveList
    BrowserPlus.run(@service) { |s|
      # Directory/File does not exist, should return error <--------------------------------- BUG 212
      #x = @test_directory_1 + "/this"
      #@list = Array.[]( x )
      #got = s.recursiveList( { 'files' => @list  } )
      #puts got

      # 3 text files.
      @list = Array.[]( @test_directory_1 )
      want = {"files" =>
              [@path_testdir + "test_directory_1",
               @path_testdir + "test_directory_1/bar1.txt",
               @path_testdir + "test_directory_1/bar2.txt",
               @path_testdir + "test_directory_1/bar3.txt"],
              "success" => true }
      got = s.recursiveList({ 'files' => @list })
      assert_equal(want, got)

      # Just one folder, no symbolic links.
      @list = Array.[]( @test_directory )
      want = {"files" =>
              [@path_testdir_noP,
               @path_testdir + "foo1.txt",
               @path_testdir + "foo2.txt",
               @path_testdir + "foo3.txt",
               @path_testdir + "sym_link",
               @path_testdir + "test_directory_1",
               @path_testdir + "test_directory_1/bar1.txt",
               @path_testdir + "test_directory_1/bar2.txt",
               @path_testdir + "test_directory_1/bar3.txt"],
              "success" => true}
      got = s.recursiveList({ 'files' => @list, "followLinks" => false })
      assert_equal(want, got)

      # Symbolic links.
      @list = Array.[]( @test_directory )
      want = {"files" =>
              [@path_testdir_noP,
               @path_testdir + "foo1.txt",
               @path_testdir + "foo2.txt",
               @path_testdir + "foo3.txt",
               if CONFIG['arch'] =~ /mswin|mingw/
                 @path_testdir + "sym_link"
               else
                 @path1 + "sym_link"
               end,
               if CONFIG['arch'] =~ /mswin|mingw/
                 @path_testdir + "sym_link/sym1.txt"
               else
                 @path1 + "sym_link/sym1.txt"
               end,
               @path_testdir + "test_directory_1",
               @path_testdir + "test_directory_1/bar1.txt",
               @path_testdir + "test_directory_1/bar2.txt",
               @path_testdir + "test_directory_1/bar3.txt"],
              "success" => true}
      got = s.recursiveList({ 'files' => @list, "followLinks" => true })
      assert_equal(want, got)

      # Mimetype => text/plain.
      @list = Array.[]( @test_directory )
      want = {"files" =>
              [@path_testdir + "foo1.txt",
               @path_testdir + "foo2.txt",
               @path_testdir + "foo3.txt",
               @path_testdir + "test_directory_1/bar1.txt",
               @path_testdir + "test_directory_1/bar2.txt",
               @path_testdir + "test_directory_1/bar3.txt"],
              "success" => true}
      got = s.recursiveList({ 'files' => @list, "followLinks" => false, "mimetypes" => ["text/plain"] })
      assert_equal(want, got)

      # Mimetype => image/jpeg ---- none present.
      @list = Array.[]( @test_directory )
      want = {"files" => [], "success" => true}
      got = s.recursiveList({ 'files' => @list, "followLinks" => false, "mimetypes" => ["image/jpeg"] })
      assert_equal(want, got)

      # Limit = 2.
      @list = Array.[]( @test_directory )
      want = {"files" =>
              [@path_testdir_noP,
               @path_testdir + "foo1.txt"],
              "success" => true}
      got = s.recursiveList({ 'files' => @list, "followLinks" => true, "limit" => 2 })
      assert_equal(want, got)

      # Callback.
      x = 1
      @list = Array.[]( @test_directory )
      got = s.recursiveList({ 'files' => @list, "followLinks" => true, "limit" => 2 }, x = x + 1)
      assert_equal( 2, x )
    }
  end


  #BrowserPlus.Directory.recursiveListWithStructure({params}, function{}())
  #Returns a nested list in "files" of objects for each of the arguments. An "object" contains the keys "relativeName" (this node's name relative to the specified directory),
  #"handle" (a filehandle for this node), and for directories "children" which contains a list of objects for each of the directory's children.
  #Recurse into directories.
  def test_recursiveListWithStructure
    BrowserPlus.run(@service) { |s|
      # Directory/File does not exist, should return error <--------------------------------- BUG 212
      # x = @test_directory_1 + "/this"
      # @list = Array.[]( x )
      # got = s.recursiveListWithStructure( { 'files' => @list  } )
      # puts got

      # 3 text files.
      @list = Array.[]( @test_directory_1 )
      want = {"files" =>
              [{"handle" =>
                @path_testdir + "test_directory_1",
                "relativeName" => "test_directory_1",
                "children" =>
                [{"handle" =>
                  @path_testdir + "test_directory_1/bar1.txt",
                  "relativeName" => "test_directory_1/bar1.txt"},
                  {"handle" =>
                   @path_testdir + "test_directory_1/bar2.txt",
                   "relativeName" => "test_directory_1/bar2.txt"},
                  {"handle" =>
                   @path_testdir + "test_directory_1/bar3.txt",
                   "relativeName" => "test_directory_1/bar3.txt"}]}],
             "success" => true}
      got = s.recursiveListWithStructure({ 'files' => @list })
      assert_equal(want, got)

      # Just one folder, no symbolic links.
      @list = Array.[]( @test_directory )
      want = {"files" =>
              [{"handle" =>
                 @path_testdir_noP,
                "relativeName" => ".",
                "children" =>
                 [{"handle" =>
                    @path_testdir + "foo1.txt",
                   "relativeName" => "./foo1.txt"},
                  {"handle" =>
                    @path_testdir + "foo2.txt",
                   "relativeName" => "./foo2.txt"},
                  {"handle" =>
                    @path_testdir + "foo3.txt",
                   "relativeName" => "./foo3.txt"},
                  {"handle" =>
                    @path_testdir + "sym_link",
                   "relativeName" => "./sym_link",
                   "children" =>[]},
                  {"handle" =>
                    @path_testdir + "test_directory_1",
                   "relativeName" => "./test_directory_1",
                   "children" =>
                    [{"handle" =>
                       @path_testdir + "test_directory_1/bar1.txt",
                      "relativeName" => "./test_directory_1/bar1.txt"},
                     {"handle" =>
                       @path_testdir + "test_directory_1/bar2.txt",
                      "relativeName" => "./test_directory_1/bar2.txt"},
                     {"handle" =>
                       @path_testdir + "test_directory_1/bar3.txt",
                      "relativeName" => "./test_directory_1/bar3.txt"}]}]}],
             "success" => true}
      got = s.recursiveListWithStructure({ 'files' => @list, "followLinks" => false })
      assert_equal(want, got)

      # Mimetype => text/plain.
      @list = Array.[]( @test_directory )
      want = {"files" =>
          [{"handle" => @path1 + ".",
            "relativeName" => ".",
            "children" =>
             [{"handle" =>
                @path_testdir + "foo1.txt",
               "relativeName" => "./foo1.txt"},
              {"handle" =>
                @path_testdir + "foo2.txt",
               "relativeName" => "./foo2.txt"},
              {"handle" =>
                @path_testdir + "foo3.txt",
               "relativeName" => "./foo3.txt"},
              {"handle" =>
                @path1 + "./test_directory_1",
               "relativeName" => "./test_directory_1",
               "children" =>
                [{"handle" =>
                   @path_testdir + "test_directory_1/bar1.txt",
                  "relativeName" => "./test_directory_1/bar1.txt"},
                 {"handle" =>
                   @path_testdir + "test_directory_1/bar2.txt",
                  "relativeName" => "./test_directory_1/bar2.txt"},
                 {"handle" =>
                   @path_testdir + "test_directory_1/bar3.txt",
                  "relativeName" => "./test_directory_1/bar3.txt"}]}]}],
         "success" => true}
      got = s.recursiveListWithStructure({ 'files' => @list, "followLinks" => false, "mimetypes" => ["text/plain"] })
      assert_equal(want, got)

      # Mimetype => image/jpeg ---- none present.
      @list = Array.[]( @test_directory )
      want = {"files" => [], "success" => true}
      got = s.recursiveListWithStructure({ 'files' => @list, "followLinks" => false, "mimetypes" => ["image/jpeg"] })
      assert_equal(want, got)

      # Size = 2.
      @list = Array.[]( @test_directory )
      want = {"files" =>
          [{"handle" =>
             @path_testdir_noP,
            "relativeName" => ".",
            "children" =>
             [{"handle" =>
                @path_testdir + "foo1.txt",
               "relativeName" => "./foo1.txt"}]}],
         "success" => true}
      got = s.recursiveListWithStructure({ 'files' => @list, "followLinks" => true, "limit" => 2 })
      assert_equal(want, got)

      # Function.
      x = 1
      @list = Array.[]( @test_directory )
      got = s.recursiveListWithStructure({ 'files' => @list, "followLinks" => true, "limit" => 2 }, x = x + 1)
      assert_equal( 2, x )
    }
  end
end
