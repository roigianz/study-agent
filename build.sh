#!/bin/sh

path=$(pwd)
url_base=https://epics.anl.gov/download/base/base-7.0.2.2.tar.gz
url_asyn=https://epics.anl.gov/download/modules/asyn4-35.tar.gz
url_stream=https://github.com/paulscherrerinstitute/StreamDevice/archive/master.zip
url_autosave=https://github.com/epics-modules/autosave/archive/R5-7-1.tar.gz
url_gateway=https://github.com/epics-extensions/ca-gateway/archive/R2-1-1-0.tar.gz
url_base3=https://epics.anl.gov/download/base/base-3.15.6.tar.gz

help()
{
    echo "Usage: $0 [clean|install|rebuild] [all|base|asyn|stream|autosave|gateway|logger]"
}

if [ $# -ge 1 ]; then
    cmd=$1
    if [ $# -ge 2 ]; then
        app=$2
    fi
else
    help
    exit 1
fi

make_app()
{
    cd $path

    if [ ! -d $path/workspace ]; then
        mkdir workspace
    fi

    mkdir workspace
    cd workspace
    mkdir $1
    cd $1
    $path/base/bin/linux-x86_64/makeBaseApp.pl -t ioc $1
    echo "" | $path/base/bin/linux-x86_64/makeBaseApp.pl -t ioc -i $1
    make
    cd ..
    chmod -R 755 $1
}

clean_base()
{
    echo "[Clean] base"
    if [ -d $path/base ]; then    
        cd $path
        rm -rf base
    fi
}

install_base()
{
    echo "[Install] base"
    cd  $path
    wget $url_base
    tar xzf base-7.0.2.2.tar.gz
    rm base-7.0.2.2.tar.gz
    mv base-7.0.2.2 base
    chmod -R 755 base
    cd base
    make
    cd ..    
}

clean_asyn()
{
    echo "[Clean] asyn"
    if [ -d $path/module/asyn4-35 ]; then
        cd $path/module
        rm -rf asyn4-35
    fi
}

install_asyn()
{
    echo "[Install] asyn"
    if [ ! -d $path/base ]; then
        echo "[Error] EPICS base is needed by a asyn module"
        exit 1
    fi

    if [ ! -d $path/module ]; then
        cd $path
        mkdir module
    fi

    cd $path/module
    wget $url_asyn
    tar xzf asyn4-35.tar.gz
    rm asyn4-35.tar.gz
    cd asyn4-35/configure
    sed 's?EPICS_BASE=\/corvette\/usr\/local\/epics-devel\/base-7.0.2?EPICS_BASE='$path'\/base?' RELEASE > RELEASE.t1
    sed 's?SUPPORT=\/corvette\/home\/epics\/devel?#SUPPORT=?' RELEASE.t1 > RELEASE.t2
    sed 's?-include $(TOP)\/..\/configure\/SUPPORT.$(EPICS_HOST_ARCH)?#-include $(TOP)\/..\/configure\/SUPPORT.$(EPICS_HOST_ARCH)?' RELEASE.t2 > RELEASE.t3
    sed 's?IPAC=$(SUPPORT)/ipac-2-14?#IPAC=?' RELEASE.t3 > RELEASE.t4
    sed 's?SNCSEQ=$(SUPPORT)/seq-2-2-5?#SNCSEQ=?' RELEASE.t4 > RELEASE
    rm RELEASE.*
    cd ..
    make
}

clean_stream()
{
    echo "[Clean] stream"
    if [ -d $path/workspace/protocol ]; then
        cd $path/workspace
        rm -rf protocol
    fi
}

install_stream()
{
    echo "[Install] stream"
    if [ ! -d $path/base ]; then
        echo "[Error] EPICS base is needed by a stream module"
        exit 1
    fi

    if [ ! -d $path/module/asyn4-35 ]; then
        echo "[Error] Asyn module is needed by a stream module"
        exit 1
    fi

    # makeBaseApp
    make_app "protocol"

    # stream
    cd $path/workspace/protocol
    wget $url_stream
    unzip master.zip
    rm master.zip
    mv StreamDevice-master stream
    cd stream/configure
    sed 's?EPICS_BASE=\/usr\/local\/epics\/base-7.0.1?EPICS_BASE='$path'\/base?' RELEASE > RELEASE.t1
    sed 's?ASYN=~\/top-7\/asyn4-33?ASYN='$path'\/module\/asyn4-35?' RELEASE.t1 > RELEASE.t2
    sed 's?CALC=~\/top-7\/SynApps\/calc-2-8?#CALC=~\/top-7\/SynApps\/calc-2-8?' RELEASE.t2 > RELEASE.t3
    sed 's?PCRE=~\/top-7\/pcre-7-2?#PCRE=~\/top-7\/pcre-7-2?' RELEASE.t4 > RELEASE
    rm RELEASE.*
    cd ..
    make

    # makeAsynStream App
    cd $path/workspace/protocol/configure
    sed -e 's?\(EPICS_BASE =.*\)?\1\nASYN='$path'\/module\/asyn4-35\nSTREAM='$path'\/workspace\/protocol\/stream?g' RELEASE > RELEASE.t1 && mv RELEASE.t1 RELEASE
    cd ../protocolApp/src
    sed 's?#protocol_DBD += xxx.dbd?protocol_DBD += drvAsynIPPort.dbd\nprotocol_DBD += stream.dbd?' Makefile > Makefile.t1
    sed 's?#protocol_LIBS += xxx?protocol_LIBS += asyn\nprotocol_LIBS += stream?' Makefile.t1 > Makefile
    rm Makefile.t1
    cd ../../
    make
}

clean_autosave()
{
    echo "[Clean] autosave"
    if [ -d $path/module/autosave5-7-1 ]; then
        cd $path/module
        rm -rf autosave5-7-1
    fi

    if [ -d $path/workspace/autosave ]; then
        cd $path/workspace
        rm -rf autosave
    fi
}

install_autosave()
{
    echo "[Install] autosave"
    if [ ! -d $path/base ]; then
        echo "[Error] EPICS base is needed by a autosave module"
        exit 1
    fi

    # autosave
    if [ ! -d $path/module ]; then
        cd $path
        mkdir module
    fi

    cd $path/module
    wget $url_autosave
    tar xzf R5-7-1.tar.gz
    rm R5-7-1.tar.gz    
    mv autosave-R5-7-1 autosave5-7-1
    cd autosave5-7-1/configure
    sed 's?EPICS_BASE=\/home\/oxygen\/MOONEY\/epics\/bazaar\/base-3.14?EPICS_BASE='$path'\/base?' RELEASE > RELEASE.t1 && mv RELEASE.t1 RELEASE
    cd ..
    make

    # makeBaseApp
    make_app "autosave"   

    # makeAutosave App
    cd $path/workspace/autosave/configure
    sed -e 's?\(EPICS_BASE =.*\)?\1\nAUTOSAVE = '$path'\/module\/autosave5-7-1?g' RELEASE > RELEASE.t1 && mv RELEASE.t1 RELEASE
    cd ../autosaveApp/src
    sed 's?#autosave_DBD += xxx.dbd?autosave_DBD += asSupport.dbd?' Makefile > Makefile.t1
    sed 's?#autosave_LIBS += xxx?autosave_LIBS += autosave?' Makefile.t1 > Makefile
    rm Makefile.t1
    cd ../../
    make

    # autosave setting
    cd $path/workspace/autosave/iocBoot/iocautosave
    sed -e 's?\(autosave_register.*\)?\1\nsave_restoreSet_Debug(0)\nsave_restoreSet_IncompleteSetsOk(1)\nsave_restoreSet_DatedBackupFiles(1)\nsave_restoreSet_NumSeqFiles(3)\nsave_restoreSet_SeqPeriodInSeconds(600)\nsave_restoreSet_RetrySeconds(60)\nsave_restoreSet_CAReconnect(1)\nsave_restoreSet_CallbackTimeout(-1)\nset_savefile_path("'$path'\/workspace/autosave/iocBoot/iocautosave", "autosave")\nset_pass0_restoreFile("auto_positions.sav")\nset_requestfile_path("'$path'\/workspace/autosave/iocBoot/iocautosave", "autosave")?g' st.cmd > st.cmd.tmp
    sed -e 's?\(iocInit.*\)?\1\ncreate_monitor_set("auto_positions.req", 5, "")?g' st.cmd.tmp > st.cmd
    rm st.cmd.tmp
    mkdir autosave
    cd autosave
    touch auto_positions.req
    touch auto_positions.sav
}

clean_gateway()
{
    echo "[Clean] gateway"
    if [ -d $path/base3 ]; then
        cd $path
        rm -rf base3
    fi

    if [ -d $path/module/gateway2-1-1 ]; then
        cd $path/module
        rm -rf gateway2-1-1
    fi    
}

install_gateway()
{
    echo "[Install] gateway"

    # base3.15.6
    cd  $path
    wget $url_base3
    tar xzf base-3.15.6.tar.gz
    rm base-3.15.6.tar.gz
    mv base-3.15.6 base3
    cd base3
    make

    # gateway
    if [ ! -d $path/module ]; then
        cd $path
        mkdir module
    fi

    cd $path/module
    wget $url_gateway
    tar xzf R2-1-1-0.tar.gz
    rm R2-1-1-0.tar.gz
    mv ca-gateway-R2-1-1-0 gateway2-1-1
    chmod -R 755 gateway2-1-1
    cd gateway2-1-1/configure
    sed 's?#EPICS_BASE=\/usr\/lib\/epics?EPICS_BASE='$path'\/base3?' RELEASE > RELEASE.t1 && mv RELEASE.t1 RELEASE
    sed 's?RULES = $(EPICS_BASE)?RULES = '$path'\/base3?' CONFIG > CONFIG.t1 && mv CONFIG.t1 CONFIG    
    cd ..
    make    
}

clean_logger()
{
    echo "[clean] logger"

    if [ -d $path/workspace/logger ]; then
        cd $path/workspace
        rm -rf logger
    fi
}

install_logger()
{
    echo "[install] logger"
    if [ ! -d $path/base ]; then
        echo "[Error] EPICS base is needed by a autosave module"
        exit 1
    fi

    # makeBaseApp
    make_app "logger"
    
    # make logger app
    cd $path/workspace/logger/iocBoot/ioclogger
    echo "epicsEnvSet(\"EPICS_IOC_LOG_INET\",\"127.0.0.1\")"  >> envPaths
    sed 's?#< envPaths?< envPaths?' st.cmd > st.cmd.tmp
    sed 's?dbLoadRecords?#dbLoadRecords?' st.cmd.tmp > st.cmd
    rm st.cmd.tmp
    echo "iocLogInit()" >> st.cmd
    chmod 755 st.cmd

    # make iocLogServer
    cd $path/workspace/logger/iocBoot/ioclogger
    mkdir log
    cd log
    touch ioc.log
    cd ..
    chmod -R 755 log
    touch iocLogServer.sh
    echo "#!/bin/sh" >> iocLogServer.sh
    echo "export EPICS_IOC_LOG_FILE_NAME=$path/workspace/logger/iocBoot/ioclogger/log/ioc.log" >> iocLogServer.sh
    echo "$path/base/bin/linux-x86_64/iocLogServer" >> iocLogServer.sh
    chmod 755 iocLogServer.sh
}

rm build.log
(case $app in
    all)
        case $cmd in
            clean)                
                time clean_base
                time clean_asyn
                time clean_stream
                time clean_autosave
                time clean_gateway
                time clean_logger
                if [ -d $path/module ]; then
                    cd $path
                    rm -rf module
                fi
                if [ -d $path/workspace ]; then
                    cd $path
                    rm -rf workspace
                fi
                ;;
            install)
                time install_base
                time install_asyn
                time install_stream
                time install_autosave
                time install_gateway
                time install_logger
                ;;
            rebuild)
                time clean_base
                time install_base
                time clean_asyn
                time install_asyn
                time clean_stream
                time install_stream
                time clean_autosave
                time install_autosave
                time clean_gateway
                time install_gateway
                time clean_logger
                time install_logger                
                ;;
            *)
                help
                exit 1
        esac
        ;;
    base)
        case $cmd in
            clean)
                time clean_base
                ;;
            install)
                time install_base
                ;;
            rebuild)
                time clean_base
                time install_base
                ;;
            *)
                help
                exit 1
        esac
        ;;
    asyn)
        case $cmd in
            clean)
                time clean_asyn
                ;;
            install)
                time install_asyn
                ;;
            rebuild)
                time clean_asyn
                time install_asyn
                ;;
            *)
                help
                exit 1
        esac
        ;;
    stream)
        case $cmd in
            clean)
                time clean_stream
                ;;
            install)
                time install_stream
                ;;
            rebuild)
                time clean_stream
                time install_stream
                ;;
            *)
                help
                exit 1
        esac
        ;;
    autosave)
        case $cmd in
            clean)
                time clean_autosave
                ;;
            install)
                time install_autosave
                ;;
            rebuild)
                time clean_autosave
                time install_autosave
                ;;
            *)
                help
                exit 1
        esac
        ;;
    gateway)
        case $cmd in
            clean)
                time clean_gateway
                ;;
            install)
                time install_gateway
                ;;
            rebuild)
                time clean_gateway
                time install_gateway
                ;;
            *)
                help
                exit 1
        esac
        ;;
    logger)
        case $cmd in
            clean)
                time clean_logger
                ;;
            install)
                time install_logger
                ;;
            rebuild)
                time clean_logger
                time install_logger
                ;;
            *)
                help
                exit 1
        esac
        ;;
    *)
        help
        exit 1
esac) 2>&1 | tee build.log