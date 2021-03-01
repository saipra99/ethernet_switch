// Code your testbench here

`define PORTA_ADDR 'hABCD
`define PORTB_ADDR 'h1234


//******************Packet*********************

class Packet;
  
  rand bit[31:0] dest_addr;
  rand bit[31:0] src_addr;
  
  rand byte pkt_data[$];
  
  rand bit[31:0] crc_data;
  
  byte pkt_full[$];
  
  int pkt_size_bytes;
  
  bit[31:0] pkt_mon_data[$];
  
  constraint address{dest_addr inside {'hABCD,'h1234};
                     src_addr inside  {'hABCD,'h1234};
                    }
  
  constraint packet_size{pkt_data.size() >4;
                         pkt_data.size() <12;
                         pkt_data.size() %4 ==0; //equally parition while driving
                        }
  
  function void post_randomize();  //Override the results of random
    int size_d;
    pkt_size_bytes =pkt_data.size() +4+4+4;
    size_d =pkt_data.size();
    
    for(int i=0;i<4;i++)
      begin
        pkt_full.push_back(dest_addr >> i*8);
      end
    
    for(int i=0;i<4;i++)
      begin
        pkt_full.push_back(src_addr>>i*8);
      end
    
    for(int i=0;i<size_d;i++)
      begin
        pkt_full.push_back(pkt_data[i]);
      end
    
    for(int i=0;i<4;i++)
      begin
        pkt_full.push_back(crc_data>>i*8);
      end
    
  endfunction
  
  function string convert2str();
    string s="";
    s= $sformatf("[Transaction] Dest : 0x%0h Source: 0x%0h CRC: 0x%0h",dest_addr,src_addr,crc_data);
    return s;
  endfunction
  
  function bit compare_pkt(Packet pkt);
    if((this.dest_addr==pkt.dest_addr) && (this.src_addr==pkt.src_addr) &&
       (this.crc_data==pkt.crc_data) && data_match(this.pkt_mon_data,pkt.pkt_mon_data))
      begin
        return 1'b1; 
      end
    return 1'b0;
  endfunction
  
  function bit data_match(bit[31:0] exp_data[$],bit[31:0] act_data[$]);
    
    int flag=0;
    
    if(exp_data.size()==act_data.size())
      
      begin
        int size =exp_data.size();
        
        for(int i=0;i< size ;i++)
          begin
            
            if(exp_data[i] ^ act_data[i] ==32'b0)
              begin
                flag=1;
              end
            
            else
              
              begin
                flag=0;
                break; 
              end
          end
      end
    
    return flag;
    
  endfunction
  
endclass

//**********************Generator*****************************
    
 class generator;
   
   mailbox gen2drv;
   
   int num_pkts=4;
   
   function new(mailbox mbx);
     gen2drv=mbx;
   endfunction
   
   
   task run();
     Packet pkt;
     for(int i=0;i<num_pkts;i++)
       begin
         
         pkt=new();
         assert(pkt.randomize());
         gen2drv.put(pkt);
       end
     $display("[Generator] Number of packets driven :%0d",num_pkts);
   endtask
   
 endclass

//******************************DRIVER****************************

class driver;
  
  mailbox mbx_in;
  virtual eth_if vif;
  
  function new(mailbox mbx,virtual eth_if vif);
    mbx_in=mbx;
    this.vif=vif;
  endfunction

  task run();
    Packet pkt;
    
    forever
      begin
        
        mbx_in.get(pkt);
        if(pkt.src_addr ==`PORTA_ADDR)
          begin
            drive_portA_pkt(pkt);
          end
        else if(pkt.src_addr ==`PORTB_ADDR)
          begin
            drive_portB_pkt(pkt);
          end
        else
          begin
            $display("[DRIVER] Wrong packets detected, Packets being dropped");
          end
      end
  endtask

  
  task drive_portA_pkt(Packet pkt);
    
    int count=0;
    bit[31:0] curr_dword;
    int size = pkt.pkt_size_bytes/4;
    
    
    forever @(posedge vif.clk)
      begin
        if(!vif.portAStall)
          begin
            vif.drv_cb.inSopA<=1'b0;
            vif.drv_cb.inEopA<=1'b0;
            
            curr_dword[7:0] =pkt.pkt_full[4*count];
            curr_dword[15:8] =pkt.pkt_full[4*count+1];
            curr_dword[23:16] =pkt.pkt_full[4*count+2];
            curr_dword[31:24] =pkt.pkt_full[4*count+3];
            
            $display("[%0t] [DRIVER] PortA::pkt count:%0d Data             		:0x%0h",$stime,count,curr_dword);
            
            if(count==0)
              begin
                vif.drv_cb.inSopA <=1'b1;
                vif.drv_cb.inDataA <= curr_dword;
                count=1;
              end
            else if(count==size-1)
              begin
                vif.drv_cb.inEopA <=1'b1;
                vif.drv_cb.inDataA <= curr_dword;
                count++;
              end
            else if(count==size)
              begin
                count=0;
                break;
              end
            else 
              begin
                vif.drv_cb.inDataA<=curr_dword;
                count++;
              end
          end
      end
  endtask
  
  
   task drive_portB_pkt(Packet pkt);
    
    int count=0;
    bit[31:0] curr_dword;
    int size = pkt.pkt_size_bytes/4;
    
    
     forever @(posedge vif.clk)
      begin
        if(!vif.portAStall)
          begin
            vif.drv_cb.inSopB<=1'b0;
            vif.drv_cb.inEopB<=1'b0;
            
            curr_dword[7:0] =pkt.pkt_full[4*count];
            curr_dword[15:8] =pkt.pkt_full[4*count+1];
            curr_dword[23:16] =pkt.pkt_full[4*count+2];
            curr_dword[31:24] =pkt.pkt_full[4*count+3];
            
            $display("[%0t] [DRIVER] PortB::pkt count:%0d Data :0x%0h",$stime,count,curr_dword);
            
            if(count==0)
              begin
                vif.drv_cb.inSopB <=1'b1;
                vif.drv_cb.inDataB <= curr_dword;
                count=1;
              end
            else if(count==size-1)
              begin
                vif.drv_cb.inEopB <=1'b1;
                vif.drv_cb.inDataB <= curr_dword;
                count++;
              end
            else if(count==size)
              begin
                count=0;
                break;
              end
            else 
              begin
                vif.drv_cb.inDataB<=curr_dword;
                count++;
              end
          end
      end
  endtask
  
endclass

//************************Monitor********************

 class monitor;
   
   virtual eth_if vif;
   mailbox mon2sbd[4];
   
   function new(mailbox mbx[4],virtual eth_if vif);
     mon2sbd=mbx;
     this.vif=vif;
   endfunction
   
   task run();
     fork
       sample_portA_input_pkt();
       sample_portB_input_pkt();
       sample_portA_output_pkt();
       sample_portB_output_pkt();
     join
   endtask
   
   task sample_portA_input_pkt();
     Packet pkt;
     int count;
     count=0;
     
     forever @(posedge vif.clk)
       begin
         if(vif.mon_cb.inSopA)
           begin
             $display("[%0t] [MONITOR] Seeing packet on input portA",$stime);
             pkt=new();
             count=1;
             pkt.dest_addr = vif.mon_cb.inDataA;
           end
         else if(count==1)
           begin
             pkt.src_addr =vif.mon_cb.inDataA;
             count++;
           end
         else if(vif.mon_cb.inEopA)
           begin
             $display("[%0t] [MONITOR] Saw pkt on input port A",$stime);
             pkt.crc_data =vif.mon_cb.inDataA;
             count=0;
             mon2sbd[0].put(pkt);
           end
         else if(count>1)
           begin
             pkt.pkt_mon_data.push_back(vif.mon_cb.inDataA);
             count++;
           end
       end
   endtask
  
   
   task sample_portB_input_pkt();
     Packet pkt;
     int count;
     count=0;
     
     forever @(posedge vif.clk)
       begin
         if(vif.mon_cb.inSopB)
           begin
             $display("[%0t] [MONITOR] Seeing packet on input port B",$stime);
             pkt=new();
             count=1;
             pkt.dest_addr = vif.mon_cb.inDataB;
           end
         else if(count==1)
           begin
             pkt.src_addr =vif.mon_cb.inDataB;
             count++;
           end
         else if(vif.mon_cb.inEopB)
           begin
             $display("[%0t] [MONITOR] Saw pkt on input port B",$stime);
             pkt.crc_data =vif.mon_cb.inDataB;
             count=0;
             mon2sbd[1].put(pkt);
             
           end
         else if(count>1)
           begin
             pkt.pkt_mon_data.push_back(vif.mon_cb.inDataB);
             count++;
           end
       end
   endtask
   
   task sample_portB_output_pkt();
     Packet pkt;
     int count;
     count=0;
     
     forever @(posedge vif.clk)
       begin
         if(vif.mon_cb.outSopB)
           begin
             $display("[%0t] [MONITOR] Seeing packet on output port B",$stime);
             pkt=new();
             count=1;
             pkt.dest_addr = vif.mon_cb.outDataB;
           end
         else if(count==1)
           begin
             pkt.src_addr =vif.mon_cb.outDataB;
             count++;
           end
         else if(vif.mon_cb.outEopB)
           begin
             $display("[%0t] [MONITOR] Saw pkt on output port B",$stime);
             pkt.crc_data =vif.mon_cb.outDataB;
             count=0;
             mon2sbd[3].put(pkt);
           end
         else if(count>1)
           begin
             pkt.pkt_mon_data.push_back(vif.mon_cb.outDataB);
             count++;
           end
       end
   endtask
   
   task sample_portA_output_pkt();
     Packet pkt;
     int count;
     count=0;
     
     forever @(posedge vif.clk)
       begin
         if(vif.mon_cb.outSopA)
           begin
             $display("[%0t] [MONITOR] Seeing packet on output portA",$stime);
             pkt=new();
             count=1;
             pkt.dest_addr = vif.mon_cb.outDataA;
           end
         else if(count==1)
           begin
             pkt.src_addr =vif.mon_cb.outDataA;
             count++;
           end
         else if(vif.mon_cb.outEopA)
           begin
             $display("[%0t] [MONITOR] Saw pkt on input port A",$stime);
             pkt.crc_data =vif.mon_cb.outDataA;
             count=0;
             mon2sbd[2].put(pkt);
           end
         else if(count>1)
           begin
             pkt.pkt_mon_data.push_back(vif.mon_cb.outDataA);
             count++;
           end
       end
   endtask
   
 endclass


//************************Scoreboard***********************

class scoreboard;
  
  virtual eth_if vif;
  mailbox mbx_in[4];
  
  function new(mailbox mbx[4]);
    mbx_in=mbx;
    this.vif=vif;
  endfunction
  
  
  task run();
    fork
      get_and_process_pkt(0);
      get_and_process_pkt(1);
      get_and_process_pkt(2);
      get_and_process_pkt(3);
    join_none
    
  endtask
  
  Packet exp_pkt_portA[$];
  Packet exp_pkt_portB[$];
  
  
  task get_and_process_pkt(int port);
   Packet pkt;
    $display("[%0t] [CHECKER] Pkt::on port= %0d",$stime,port);
    
    forever
      begin
        mbx_in[port].get(pkt);
        if(port<2)
          gen_exp_pkt(pkt);
        else
          check_exp_act_pkt(pkt,port);
      end
  endtask
  
  function void  gen_exp_pkt(Packet pkt);
    
    if(pkt.dest_addr==`PORTA_ADDR)
      begin
        $display("[%0t] [CHECKER] Received pkt on queue A",$stime);
        exp_pkt_portA.push_back(pkt);
      end
    else
      begin
        exp_pkt_portB.push_back(pkt);
        $display("[CHECKER] Received pkt on queue B");
      end
  endfunction
  
  function void check_exp_act_pkt(Packet pkt,int port);
    Packet exp;
    
    if(port==0)
      begin
        exp=exp_pkt_portA.pop_front();
        $display("Display the expected packet %s",exp.convert2str());
      end
    else
      begin
        exp=exp_pkt_portB.pop_front();
      end
    
    if(pkt.compare_pkt(exp))
      $display("[%0t] [CHECKER] Data integrity maintained on output port :%c",$stime,(63+port));
    else
      $display("[%0t] [CHECKER] Failed packet on output port:%c mismatches",$stime,(63+port));
    
  endfunction
  
  
endclass

//***************************ENVIRONMENT*************************

class environment;
  
  generator g0;
  driver d0;
  monitor m0;
  scoreboard sb0;
  
  virtual eth_if rtl_if;
  string name;
  
  mailbox gen2drv;
  mailbox mon2sbd[4];
  
  
  function new(string name,virtual eth_if vif);
    this.name=name;
    this.rtl_if=vif;
    
    gen2drv=new();
    
    for(int i=0;i<4;i++)
      begin
        mon2sbd[i]=new();
       $display("Create mailbox =%0d for mon-check",i);
      end
    
    g0= new(gen2drv);
    d0= new(gen2drv,rtl_if);
    
    m0=new(mon2sbd,rtl_if);
    sb0=new(mon2sbd);
    
  endfunction
  
  
  task run();
    
    fork
      g0.run();
      d0.run();
      m0.run();
      sb0.run();
    join
    
  endtask
  
endclass

//********************INTERFACE***********************

interface eth_if(input clk);
  
  logic resetN;
  logic [31:0] inDataA;
  logic inSopA;
  logic inEopA;
  logic inSopB;
  logic inEopB;
  logic [31:0] inDataB;
  logic outSopA;
  logic outEopA;
  logic [31:0] outDataA;
  logic outSopB;
  logic outEopB;
  logic[31:0] outDataB;
  logic portAStall;
  logic portBStall;
  
  clocking drv_cb @(posedge clk);
    default input #2ns output #2ns;
    
    input portAStall;
    input portBStall;
    output inDataA;
    output inDataB;
    output inSopA;
    output inEopA;
    output inEopB;
    output inSopB;
    
  endclocking
  
  clocking mon_cb@(posedge clk);
    default input #2ns output #2ns;
    
    input clk;
    input resetN;
    input inDataA;
    input inDataB;
    input inSopA;
    input inSopB;
    input inEopA;
    input inEopB;
    input outSopA;
    input outSopB;
    input outEopA;
    input outEopB;
    input portAStall;
    input portBStall;
    input outDataA;
    input outDataB;
    
  endclocking
  
  modport MONITOR(clocking mon_cb,input clk);
    
  modport DRIVER(clocking drv_cb,input clk);
       
  
  
endinterface
    
//*******************TESTBENCH_TOP*******************
    
module tb;
  
  reg clk;
  
  eth_if if_(clk);
  
  eth_sw D0(.clk(clk),
            .resetN(if_.resetN),
            .inDataA(if_.inDataA),
            .inDataB(if_.inDataB),
            .inSopA(if_.inSopA),
            .inSopB(if_.inSopB),
            .inEopA(if_.inEopA),
            .inEopB(if_.inEopB),
            .outDataA(if_.outDataA),
            .outDataB(if_.outDataB),
            .outSopA(if_.outSopA),
            .outSopB(if_.outSopB),
            .outEopA(if_.outEopA),
            .outEopB(if_.outEopB),
            .portAStall(if_.portAStall),
            .portBStall(if_.portBStall));
  
  always #10 clk = ~clk;
  
  environment pkt_env;
  
  
  initial
    
    begin
      clk=0;
      if_.resetN =0;
      repeat(5) @(posedge clk);
      if_.resetN = 1;
      pkt_env =new("sample_env",if_);
      $display("Created pkt_tb env");
      
      fork
        pkt_env.run();
      join
      
      //$finish;
    end
  
    initial
      begin
       $dumpvars(1);
       $dumpfile("test_pkt.vcd");
      end

endmodule
    
//**********************END*****************************
    
    





  
    
    
    
    
    
    
    
    
  
  
  
  
  
   
   

   

   
   
           
             
             
     

              
                
            
            

    
     
    
         
         
         
     
   
   
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
                         
