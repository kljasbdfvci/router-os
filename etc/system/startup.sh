#!/bin/bash

### Wait For ttyS0 Start
#sleep 5

### Const Variable
output="/dev/ttyS0"
null_output="/dev/null"

my_print() {
   if [ $2 -eq 0 ]; then
      >&2 echo "$1...OK"
      echo -n "."
   else
      >&2 echo "$1...FAIL"
      echo -n "?"
   fi
}

initialSystem() {
   os_file_path=$1
   if [ -f "$os_file_path" ]; then
   
      ### mkdir tmp folder System
      mkdir /tmp/os
      res_mkdir=$?
      my_print "mkdir temp folder System" $res_mkdir

      ### extract System
      tar -zxvf $os_file_path -C /tmp/os 1>$null_output
      res_tar=$?
      my_print "extract System" $res_tar

      ### copy tmp files to os System
      res_cps=0
      files=$(find /tmp/os -type f)
      for tmpFile in $files
      do
         file=$(echo $tmpFile | sed "s/^\/tmp\/os//")
         tmpFileMd5sum=$(md5sum $tmpFile | cut -d ' ' -f 1 | tr -d '\n')
         fileMd5sum=""
         if [ -f "$file" ]; then
            fileMd5sum=$(md5sum $file | cut -d ' ' -f 1 | tr -d '\n')
         fi
         if [ "$tmpFileMd5sum" != "$fileMd5sum" ]; then
            cp $tmpFile $file
            res_cp=$?
            my_print "copy file $file to os System" $res_cp
            if [ $res_cp -ne 0 ]; then
               res_cps=1
            fi
         fi
      done
      my_print "copy tmp files to os System" $res_cps

      ### rm tmp folder System
      rm -rf /tmp/os
      res_rm=$?
      my_print "rm tmp folder System" $res_rm

      ### reload systemctrl
      systemctl daemon-reload
      res_systemctl=$?
      my_print "systemctl daemon-reload" $res_systemctl

      ### return
      if [ $res_mkdir = 0 ] && [ $res_tar = 0 ] && [ $res_cps = 0 ] && [ $res_rm = 0 ] && [ $res_systemctl = 0 ]; then
         return 0
      else
         return 1
      fi
   else
      ### return
      return 1
   fi
}

initialApplication() {
   app_file_path=$1
   app_untar_path=$2
   app_init_path=$3
   if [ -f "$app_file_path" ]; then

      ### make app dir Application
      mkdir -p $app_untar_path >$null_output
      res_mkdir=$?
      my_print "make app dir Application" $res_mkdir

      ### rm app files Application
      rm -rf $app_untar_path/* >$null_output
      res_rm=$?
      my_print "rm app files Application" $res_rm

      ### extract Application
      tar -xzvf $app_file_path -C $app_untar_path 1>$null_output
      res_tar=$?
      my_print "extract Application" $res_tar

      ### run init Application
      $app_init_path 1>$null_output
      res_init=$?
      my_print "run init Application" $res_init

      ### return
      if [ $res_rm = 0 ] && [ $res_tar = 0 ] && [ $res_init = 0 ] && [ $res_mkdir = 0 ]; then
         return 0
      else
         return 1
      fi
   else
      ### return
      return 1
   fi
}

decryptFile() {
   in=$1
   out=$2
   serial -s code | openssl enc -aes-256-cbc -d -in $in -out $out -pass stdin
   res_decrypt=$?
   my_print "decrypt file" $res_decrypt
   return $res_decrypt
}

### Move Cursor Down And Print Logo
printf "\n\n\n\n\n\n"
cat /etc/system/logo
printf "\n"

### Wait For Mount /memory
echo -n "Initial Storage"
for i in {1..20}
do
   ### check memory storage Mount
   mountpoint -q "/memory"
   res=$?
   my_print "$i check memory storage Mount" $res
   if [ $res -eq 0 ]; then
      break
   fi
   
   ### sleep Mount
   sleep 1
done

### System
os_file_path=$(find /disk/firmware -type f -name 'linux-os*' | sort | tail -n 1)
app_file_path=$(find /disk/firmware -type f -name 'app*' | sort | tail -n 1)
app_untar_path="/memory/app"
app_init_path="/memory/app/bin/init.sh"

if [ -f "$os_file_path" ] && [ -f "$app_file_path" ]; then

   ### System
   echo -n "Initial System"
   temp_os_file_path="/tmp/linux-os.tgz"
   decryptFile $os_file_path $temp_os_file_path
   if [ $? -eq 0 ]; then
      initialSystem $temp_os_file_path
      if [ $? -eq 0 ]; then
         echo " OK"
      else
         echo " ERROR"
      fi
   else
      echo " ERROR"
   fi
   rm -f $temp_os_file_path

   ### Application
   echo -n "Initial Application"
   temp_app_file_path="/tmp/app.tgz"
   decryptFile $app_file_path $temp_app_file_path
   if [ $? -eq 0 ]; then
      initialApplication $temp_app_file_path $app_untar_path $app_init_path
      if [ $? -eq 0 ]; then
         echo " OK"
      else
         echo " ERROR"
      fi
   else
      echo " ERROR"
   fi
   rm -f $temp_app_file_path
fi

exit 0
