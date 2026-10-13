set libname rf136x16m4h3v2
set libpath ../ip/rf136x16m4h3v2

if {![file exists $libpath/db]} {
    file mkdir $libpath/db
}

foreach libfile [glob $libpath/*.lib] {
    set base_name [file rootname [file tail $libfile]]
    read_lib $libfile
    write_lib $libname -format db -output "$libpath/db/${base_name}.db"
    remove_lib $libname
}