#!/usr/bin/env ruby
require 'rubygems'
require 'choice'

Choice.options do
   header 'Application options:'
   option :ncd, :required => false do
      short '-n'
      desc 'The NCD_FILE containing placed BRAMs'
   end
   option :xdl, :required => false do
      short '-x'
      desc 'use specified XDL file, or generate from NCD_FILE)'
   end
   option :bmm, :required => true do
      short '-o'
      desc 'BMM_FILE to create'
   end
   option :elf, :required => false do
      short '-f'
      desc 'elf File to place in memory'
   end
   option :bit, :required => false do
      short '-b'
      desc 'bitfile to update'
   end
   option :loc, :required => false do
      short '-l'
      desc 'Include Location in BMM file'
   end
   separator 'Common:'
   option :help do
      short '-h'
      long '--help'
      desc 'Show this message.'
   end
end

if Choice.choices.xdl
    xdlfile = Choice.choices.xdl
elsif Choice.choices.ncd
   puts 'running ncd2xdl'
   system("xdl -ncd2xdl #{Choice.choices.ncd} #{Choice.choices.ncd+'.xdl'}")
   xdlfile = Choice.choices.ncd+'.xdl'
else
   puts 'this script needs an xdl or ncd file.'
   abort
end

file = File.new(xdlfile, 'r')
mems = Array.new
blocks = Array.new
cpus = Array.new

if system("which data2mem") == false
   puts 'ISE Settings script not sourced'
   abort
end

#Search blockram in netlist
file.each_line("\n") do |row|
   this = row.scan(/^inst \"(.+memory.+)\" \".*RAMB16_([\w\d]+)/)
   if this[0]     
      mems.push(this[0])
   end
end

mems.each do |mem|
   cpu_no = mem[0].scan(/^\w+(\d)/)[0][0].to_i
   if blocks[cpu_no]
      blocks[cpu_no].push(mem)
   elsif
      blocks[cpu_no] = Array.new
      blocks[cpu_no].push(mem)
      cpus.push(cpu_no)
   end
end

if cpus.size() == 0
   puts "No RAMB16 Blockram found."
   abort
end
puts "Found #{cpus.size()} CPU(s) in the netlist."

File.open(Choice.choices.bmm, 'w') do |bmm|
   bmm.puts "ADDRESS_MAP mpsoc PPC405 0"
   cpus.each do |cpu|
      size = 2048 * blocks[cpu].count() -1
      msb=31
      bmm.puts "    ADDRESS_SPACE memory#{cpu} RAMB16 [0x00000000:0x0000#{size.to_s(16)}]"
      bmm.puts "        BUS_BLOCK"
      blocks[cpu].reverse.each do |mem|
         lsb = msb - 32 / blocks[cpu].count() + 1;
         if Choice.choices.loc or Choice.choices.elf
            loc = " PLACED = #{mem[1]}"
         else
            loc = ""
         end
         bmm.puts "            #{mem[0]} [#{msb}:#{lsb}]#{loc};"
         msb = lsb - 1
      end
      bmm.puts "        END_BUS_BLOCK;"
      bmm.puts "    END_ADDRESS_SPACE;"
   end
   bmm.puts "END_ADDRESS_MAP;"
end

#Check syntax of output
if system("data2mem -bm #{Choice.choices.bmm}") == false
   puts 'Syntax error in bmm file.'
   abort
end
puts 'bmm Syntax ok.'
if Choice.choices.elf and Choice.choices.bit
   puts 'patching bitfile...'
   if system("data2mem -bm #{Choice.choices.bmm} -bd #{Choice.choices.elf} -bt #{Choice.choices.bit} -o b tmp.bit ") == false
      puts 'patching failed. see data2mem error.'
      abort
   end
   system("mv tmp.bit #{Choice.choices.bit}")
   puts 'Done.'
end

