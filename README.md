# rhcsa-10-practice-test-scripts

Bash scripts which perform all tasks in the practice exams in Sander Van Vugts RHCSA 9 EX200 exam preparation guide.


## Why? 

After recently burning out while studying for the RHCSA 10 exam , I wanted to find ways to engage with the material in a direct way with a project that would force me to use the knowledge required for the exam. I found one of my weakpoints was bash scripting , so I decided what better way to learn than to automate all the practice tests found in the RHCSA exam practice tests. 

You can find the practice tests in Sander Van Vugt RHCSA 9 Exam Preparation guide, or you can see all exams listed on my wiki using the link ![here](https://ryanm.dev/docs/Linux/RHEL/book-practice/)

Of course the only tasks not covered in the script are resetting the root password , I skipped over the tasks involving containers as of this time of writing ( 01-13-2026 ) the objectives for RHCSA 10 do not include containers. In the future this may change as I plan on taking RHCE upon passing the RHCSA 10 exam.  

Changes made to configuration files are backed up with a "\*.bak" file extension , the cleanup functions should restore this backup , however in the event this fails , always be sure to backup /etc/login.defs and /etc/fstab just in case. 

## Installation 

Set as executable and run desired script 

```bash
chmod +x ./test-scripts/*.sh 
```

## Usage 

> You can run any of the "create_\*"  and "cleanup_\*" functions by passing the name as the first command argument 

```bash
# Runs only the cleanup_create_lvm function 
./test-a.sh cleanup_create_lvm

# Run all functions ( complete test ) 
./test-a.sh test

# Run all cleanup functions 
./test-a.sh cleanup 
```


