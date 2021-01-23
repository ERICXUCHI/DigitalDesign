`timescale 1ns / 1ps

module project_music(
en,clk,product_select,select_item,selection,cash_type,confirm,add_num,mode,add,clear,
seg_en,seg_out,beep
    );
     input[1:0] en;//使能信号，负责控制是否进入购买状态
     input clk;//时钟信号
     input[1:0] product_select;//query step的选择商品
     input[2:0] select_item;//假设有三种商品，用拨码开关选择三种商品
     input[2:0] selection;
     input[2:0] add_num;//每件商品的购买数量
     input[3:0] cash_type;//共有4种钞票类型，分别为1，2，5，10元
     input confirm;
     input mode;
     input [1:0] add;
     input clear;
     ////query
     reg [13:0] product_id;   //商品名称
     reg [6:0] product_price; //商品价格
     reg [13:0] product_number_vis; //商品数量
     
     
     reg [7:0] bit_select;//高电平有效
     reg [6:0] seg_select;//高电平有效
     
     reg [55:0] total_seg;//状态X的8位上每个数码管的out信号
     
     reg clkout1,clkout2;  //分频器
     reg [2:0] scan_cnt;  
     reg [2:0] state0; //状态
     reg [31:0] cnt1; //扫描分频（快）
     reg [63:0] cnt2; //状态机分频（慢）
     
     parameter period1 = 200000, period2 = 80000000;
     parameter seg_A =  7'b1110111,seg_B = 7'b1111100,seg_C = 7'b0111001,seg_D = 7'b1011110,seg_E = 7'b1111001,seg_Zero = 7'b0111111,seg_One = 7'b0000110,seg_Two = 7'b1011011,seg_Three = 7'b1001111,seg_Four = 7'b1100110,seg_Five = 7'b1101101,seg_Six = 7'b1111101,seg_Seven = 7'b0100111,seg_Eight = 7'b1111111,seg_Nine = 7'b1101111,seg_Null= 7'b0110111;
                 
     ////query
     
     
     reg[2:0] add_type;//辅助增加购买数量
     reg[3:0] adding1 = 0,adding2 = 0,adding3 = 0;
     reg[3:0] left1=10,left2=10,left3=10;//每种商品的原始数量，分别为每件商品为十件
     reg[3:0] price1=3,price2=5,price3=8;//三种商品对应的单价，分别为3元，5元，8元

     reg[3:0] stage=4'b0000;//构造状态机,0000为初始状态
     parameter 
	  calculate=4'b0010,
	  print1=4'b0011,
	  print2=4'b0100,
	  print4=4'b0101,
	  print5=4'b0110,
	  print7=4'b0111,
      print8=4'b1000,
	  repay=4'b1110,
	  change=4'b1111;//定义参数，负责改变状态机的状态

     reg[6:0] money_shouldPay;//一共需要的钱数

     reg[7:0] bright0=8'b11111111,bright1=8'b11111110,bright2=8'b11111101,bright4=8'b11110111,bright5=8'b11101111,
     bright7=8'b10111111,bright8=8'b01111111,number1=8'b11111111,number2=8'b11111111,number4=8'b11111111,number5=8'b11111111,
     number7=8'b11111111,number8=8'b11111111;// 负责控制哪一展灯亮和显示什么数字

     reg[3:0] sold_amount1=0,sold_amount2=0,sold_amount3=0;//每一件商品卖出的件数

     reg[31:0] count=0,minCount=0,secondCount=0;//分频器，min是10纳秒级别，second是秒数，每十亿纳秒为一秒,count是数码管的分频

     reg[3:0] hasPayed=4'b0000;//辅助付款4bit

     reg[10:0] money_hasPayed=0, totalMoney_inMachine=0;

     reg[0:0] repayFlag=0,changeFlag=0;

     output reg[7:0] seg_en,seg_out;//在7段数码显示管上显示对应的信息，seg_en表示哪一展灯亮，seg_out表示这盏灯显示什么
     output beep;					
     reg beep_r;                
     reg[7:0] state;//蜂鸣器状态，控制它的频率，即声音
     reg[16:0]count2,count_end;
     reg[23:0]count1;
     
     parameter     
             L1 = 17'd95414,
             L2 = 17'd85034,
             L3 = 17'd75757,
             L4 = 17'd71633,
             L5 = 17'd63775,
             L6 = 17'd56818,
             L7 = 17'd50607,
             M1 = 17'd47801,
             M2 = 17'd42589,
             M3 = 17'd37936,
             M4 = 17'd35816,
             M5 = 17'd31887,
             M6 = 17'd28409,
             M7 = 17'd25303,
             H1 = 17'd23900,
             H2 = 17'd21276,
             H3 = 17'd18968,
             H4 = 17'd17895,
             H5 = 17'd15943,
             H6 = 17'd14204,
             H7 = 17'd12651;
     parameter TIME = 12000000;                                
     assign beep = beep_r;
                 
     ////admin module
     
     reg [3:0] addAble1,addAble2,addAble3;
     reg [1:0] temp=2'b00;
     reg [3:0]amountAdd;
     reg clkouta;  //分频器
     reg [31:0] cnt;
     reg [2:0] scan_cnta;
     reg[7:0] digit1=8'b11111111,digit2=8'b11111111,digit4=8'b11111111,digit5=8'b11111111,
          digit7=8'b11111111,digit8=8'b11111111;
     parameter Search=1'b0;
     parameter Add=1'b1;
     
     
     ////            
    always@(posedge clk) begin//单独一个分频器，蜂鸣器工作原理
         if (confirm) begin
             count2 <= count2 + 1'b1;        
             if(count2 == count_end) begin    
                 count2 <= 17'h0;            
                 beep_r <= !beep_r;        
             end
         end
     end
     
     ////query分频器
    always @(posedge clk)     //分频器部分
         begin
             if(en!=2'b01)begin
                 cnt1 <= 0;
                 clkout1 <= 0;
             end
             else begin
                 if(cnt1 == (period1 >> 1) - 1)begin
                     clkout1 <= ~clkout1;
                     cnt1 <= 0;
                 end
                 else
                     cnt1 <= cnt1+1;
             end
         end
         
    always @(posedge clk)
         begin
             if(en!=2'b01)begin
                 cnt2 <= 0;
                 clkout2 <= 0;
             end
             else begin
                 if(cnt2 == (period2 >> 1) - 1)begin  
                     clkout2 <= ~clkout2;
                     cnt2 <= 0;
                 end
                 else
                     cnt2 <= cnt2+1;
             end
         end
         
    always @(posedge clkout1) //扫描分频器
         begin
             if(en!=2'b01)
                 scan_cnt <= 0;
              else begin
                 scan_cnt <= scan_cnt +1;
                 if(scan_cnt == 3'd7) scan_cnt <= 0;
              end
         end
         
    always @(posedge clkout2)  //分不同阶段
         begin   
             if(en!=2'b01)
             begin
                 state0 <= 3'd0;
             end
             else begin
                 state0 <= state0 + 1;
                 if(state0 == 3'd7) state0 <= 3'd0;
             end
         end
         
     ////querydone
     
     ////admin分频器
     
    always @(posedge clk)     //分频器部分
         begin
             if(en != 2'b10)begin
                 cnt <= 0;
                 clkouta <= 0;
             end
             else begin
                 if(cnt == 20000)begin
                     clkouta <= ~clkouta;
                     cnt <= 0;
                 end
                 else
                     cnt <= cnt+1;
             end
         end
    always@(posedge clkouta)
         begin 
               if(en == 2'b10)begin
                   if(scan_cnta == 3'd6) scan_cnta <= 0;
                   else scan_cnta <= scan_cnta+1;
               end
         end
     ////admindone
     
    always@(posedge clk)
        begin
        case(en)
      2'b01:begin////query
        repayFlag<=0; changeFlag<=0;
        seg_out <= {1'b1,~(seg_select[6:0])};  //输出的每个显示管
        seg_en <= ~bit_select;  //输出哪个显示管
            case(product_select)             //由拨码开关选择商品
            2'b01:begin
                  product_id ={seg_One,seg_A};          //名称为1A
                 product_price = seg_Three;                 //价格为三
                  case(left1[3:0])                                       //商品数量剩余（1~10）
                       4'b0000:product_number_vis = {seg_Zero,seg_Zero};    
                       4'b0001:product_number_vis = {seg_Zero,seg_One};
                       4'b0010:product_number_vis = {seg_Zero,seg_Two};
                       4'b0011:product_number_vis = {seg_Zero,seg_Three};
                       4'b0100:product_number_vis = {seg_Zero,seg_Four};
                       4'b0101:product_number_vis = {seg_Zero,seg_Five};
                       4'b0110:product_number_vis = {seg_Zero,seg_Six};
                       4'b0111:product_number_vis = {seg_Zero,seg_Seven};
                       4'b1000:product_number_vis = {seg_Zero,seg_Eight};
                       4'b1001:product_number_vis = {seg_Zero,seg_Nine};
                       4'b1010:product_number_vis = {seg_One,seg_Zero};
                       endcase
                                              
                        end
                    2'b10:begin
                        product_id = {seg_Two, seg_B};       //名称为1A
                        product_price = seg_Five;                    //价格为五
                       case(left2[3:0])                                                //商品数量剩余（1~10）
                        4'b0000:product_number_vis = {seg_Zero,seg_Zero};
                        4'b0001:product_number_vis = {seg_Zero,seg_One};
                        4'b0010:product_number_vis = {seg_Zero,seg_Two};
                        4'b0011:product_number_vis = {seg_Zero,seg_Three};
                        4'b0100:product_number_vis = {seg_Zero,seg_Four};
                        4'b0101:product_number_vis = {seg_Zero,seg_Five};
                        4'b0110:product_number_vis = {seg_Zero,seg_Six};
                        4'b0111:product_number_vis = {seg_Zero,seg_Seven};
                        4'b1000:product_number_vis = {seg_Zero,seg_Eight};
                        4'b1001:product_number_vis = {seg_Zero,seg_Nine};
                        4'b1010:product_number_vis = {seg_One,seg_Zero};
                        endcase
                                    end
                      2'b11:begin
                        product_id = {seg_Three,seg_C};         //名称为3C
                        product_price = seg_Eight;              //价格为八
                       case(left3[3:0])                                              //商品数量剩余（1~10）
                          4'b0000:product_number_vis = {seg_Zero,seg_Zero};
                          4'b0001:product_number_vis = {seg_Zero,seg_One};
                          4'b0010:product_number_vis = {seg_Zero,seg_Two};
                          4'b0011:product_number_vis = {seg_Zero,seg_Three};
                          4'b0100:product_number_vis = {seg_Zero,seg_Four};
                          4'b0101:product_number_vis = {seg_Zero,seg_Five};
                          4'b0110:product_number_vis = {seg_Zero,seg_Six};
                          4'b0111:product_number_vis = {seg_Zero,seg_Seven};
                          4'b1000:product_number_vis = {seg_Zero,seg_Eight};
                          4'b1001:product_number_vis = {seg_Zero,seg_Nine};
                          4'b1010:product_number_vis = {seg_One,seg_Zero};
                          endcase
                       end
                  default:
                       begin                                                            //在未选择的情况下，显示  NN N NS( Null Select)
                         product_id = {seg_Null,seg_Null};
                         product_price = seg_Null;
                         product_number_vis = {seg_Null,seg_Five}; 
                       end
                 endcase
                                              
                
                
                        case (scan_cnt)                                                             //扫描分频器
                            3'b000: bit_select = 8'b0000_0001;
                            3'b001: bit_select = 8'b0000_0010;
                            3'b010: bit_select = 8'b0000_0100;
                            3'b011: bit_select = 8'b0000_1000;
                            3'b100: bit_select = 8'b0001_0000;
                            3'b101: bit_select = 8'b0010_0000;
                            3'b110: bit_select = 8'b0100_0000;
                            3'b111: bit_select = 8'b1000_0000;
                        endcase
                
                        case (scan_cnt)
                            3'd0:seg_select=total_seg[6:0];
                            3'd1:seg_select=total_seg[13:7];
                            3'd2:seg_select=total_seg[20:14];
                            3'd3:seg_select=total_seg[27:21];
                            3'd4:seg_select=total_seg[34:28];
                            3'd5:seg_select=total_seg[41:35];
                            3'd6:seg_select=total_seg[48:42];
                            3'd7:seg_select=total_seg[55:49]; 
                            default:seg_select=7'b0000000;
                        endcase

            case(state0)                                                                                                    //滚动实现，分为八个阶段，分别表示每一秒的显示
                  3'd0: total_seg = {7'b0,7'b0,7'b0,7'b0,7'b0,7'b0,7'b0,product_id[13:7]};
                  3'd1: total_seg = {7'b0,7'b0,7'b0,7'b0,7'b0,7'b0,product_id[13:7],product_id[6:0]};
                  3'd2: total_seg = {7'b0,7'b0,7'b0,7'b0,7'b0,product_id[13:7],product_id[6:0],7'b0};
                  3'd3: total_seg = {7'b0,7'b0,7'b0,7'b0,product_id[13:7],product_id[6:0],7'b0,product_price};
                  3'd4: total_seg = {7'b0,7'b0,7'b0,product_id[13:7],product_id[6:0],7'b0,product_price,7'b0};
                  3'd5: total_seg = {7'b0,7'b0,product_id[13:7],product_id[6:0],7'b0,product_price,7'b0,product_number_vis[13:7]};
                  3'd6: total_seg = {7'b0,product_id[13:7],product_id[6:0],7'b0,product_price,7'b0,product_number_vis[13:7],product_number_vis[6:0]};
                  3'd7: total_seg = {product_id[13:7],product_id[6:0],7'b0,product_price,7'b0,product_number_vis[13:7],product_number_vis[6:0],7'b0};
                    default:total_seg = 56'd0;
                   endcase
                end////query
        
        2'b11:
        begin
          minCount <= minCount+1;
        if(minCount==100000000)
            begin
            secondCount<=secondCount+1;
            minCount<=0;
            end
        else begin
            minCount <= minCount+1;
            end//此分频器对应倒计时显示
//
        if (confirm & money_hasPayed >= money_shouldPay) begin
             if(count1 < TIME)           
             count1 = count1 + 1'b1;
         else begin
             count1 = 24'd0;
             if(state == 8'd40)
                 state = 8'd0;
             else
                 state = state + 1'b1;
             case(state)
                 8'd0:count_end = L1;  
                 8'd1:count_end = L2;
                 8'd2:count_end = L3;
                 8'd3:count_end = L4;
                 8'd4:count_end = L5;
                 8'd5:count_end = L6;
                 8'd6:count_end = L7;
                 8'd7:count_end = M1;
                 8'd8:count_end = M2;  
                 8'd9:count_end = M3;
                 8'd10:count_end = M4;
                 8'd11:count_end = M5;
                 8'd12:count_end = M6;
                 8'd13:count_end = M7;
                 8'd14:count_end = H1;
                 8'd15:count_end = H2;
                 8'd16:count_end = H3;  
                 8'd17:count_end = H4;
                 8'd18:count_end = H5;
                 8'd19:count_end = H6;
                 8'd20:count_end = H7;
                 8'd21:count_end = H6;
                 8'd22:count_end = H5;  
                 8'd23:count_end = H4;
                 8'd24:count_end = H3;
                 8'd25:count_end = H2;
                 8'd26:count_end = H1;
                 8'd27:count_end = M7;
                 8'd28:count_end = M6;  
                 8'd29:count_end = M5;
                 8'd30:count_end = M4;
                 8'd31:count_end = M3;
                 8'd32:count_end = M2;
                 8'd33:count_end = M1;
                 8'd34:count_end = L7;  
                 8'd35:count_end = L6;
                 8'd36:count_end = L5;
                 8'd37:count_end = L4;
                 8'd38:count_end = L3;
                 8'd39:count_end = L2;
                 8'd40:count_end = L1;
                 //default: count_end = L1;对应蜂鸣器的信号
             endcase
            end
        end
     
        else if(confirm & money_hasPayed < money_shouldPay)
            begin
                if(count1 < TIME)
                     count1 = count1 + 1'b1;
                 else begin
                     count1 = 24'd0;
                     if(state == 8'd1)
                         state = 8'd0;
                     else
                         state = state + 1'b1;
                     case(state)
                         8'd0:count_end = L1;  
                         8'd1:count_end = L1;
                         //default: count_end = L1;
                     endcase
                 end
            end
//付款失败的信号                
            
        case (stage)
          4'b0000:
            begin

                    case(select_item[2:0])
                    3'b001:money_shouldPay <= price1 * adding1;
                    3'b010:money_shouldPay <= price2 * adding2;
                    3'b011:money_shouldPay <= price1 * adding1 + price2 * adding2;
                    3'b100:money_shouldPay <= price3 * adding3;
                    3'b101:money_shouldPay <= price1 * adding1 + price3 * adding3;               
                    3'b110:money_shouldPay <= price2 * adding2 + price3 * adding3;
                    3'b111:money_shouldPay <= price1 * adding1 + price2 * adding2 +price3 * adding3;
                    default:money_shouldPay <= 0;
                    endcase
                    stage <= calculate;
            end
           

            calculate:
             begin
             if(money_hasPayed >= money_shouldPay & confirm)
               begin
               
               totalMoney_inMachine <= totalMoney_inMachine + money_shouldPay;//一共卖出了多少钱
               
               stage <= change;//进入找零状态
               changeFlag <= 1;
                    
               end
               
               
            else if(secondCount==60)//60秒倒计时结束，用户付款金额不足
               begin
               stage <= repay;
               repayFlag <= 1;
               end
               else if(secondCount < 60)// 在60秒之内可以付款，下面即用拨码开关进行付款
             
                begin
                    if(cash_type[0]&~hasPayed[0])
                      begin
                      hasPayed[0]<=1;
                      money_hasPayed<=money_hasPayed+1'b1;
                      end
                    else if(cash_type[1]&~hasPayed[1])
                      begin
                      hasPayed[1]<=1;
                      money_hasPayed<=money_hasPayed+2'b10;
                      end
                    else if(cash_type[2]&~hasPayed[2])
                      begin
                      hasPayed[2]<=1;
                      money_hasPayed<=money_hasPayed+3'b101;
                      end
                    else if(cash_type[3]&~hasPayed[3])
                      begin
                       hasPayed[3]<=1;
                       money_hasPayed<=money_hasPayed+4'b1010;
                       end
                       
                    if(~cash_type[0])
                       hasPayed[0]<=0;
                     if(~cash_type[1])
                       hasPayed[1]<=0;
                     if(~cash_type[2])
                       hasPayed[2]<=0;
                     if(~cash_type[3])
                       hasPayed[3]<=0;
                       
                      //以上目的为了实现拨码开关每拨一次可以自动增加钱数
                      
                      
                     if(select_item[0] & left1 > 0 & add_num[0] & ~add_type[0])
                        begin
                        add_type[0] <= 1;
                        adding1 <= adding1 + 1;
                        sold_amount1 <= sold_amount1 + 1;
                        left1 <= left1 - 1;
                        end
                     else if(select_item[1] & left2 > 0 & add_num[1] & ~add_type[1])
                        begin
                        add_type[1] <= 1;
                        adding2 <= adding2 + 1;
                        sold_amount2 <= sold_amount2 + 1;
                        left2 <= left2 - 1;
                        end
                     else if(select_item[2] & left3 > 0 & add_num[2] & ~add_type[2])
                        begin
                        add_type[2] <= 1;
                        adding3 <= adding3 + 1;
                        sold_amount3 <= sold_amount3 + 1;
                        left3 <= left3 - 1;
                        end
                        
                     if(~add_num[0])
                        add_type[0] <= 0;
                     if(~add_num[1])
                        add_type[1] <= 0;
                     if(~add_num[2])
                        add_type[2] <= 0;   
                     //以上目的为了实现一件物品购买多件         
                      
                    case(money_hasPayed/10)
                       0: number8<= 8'b11000000;
                       1: number8<= 8'b11111001;
                       2: number8<= 8'b10100100;
                       3: number8<= 8'b10110000;
                       4: number8<= 8'b10011001;
                       5: number8<= 8'b10010010; 
                       6: number8<= 8'b10000010;
                       7: number8<= 8'b11111000;
                       8: number8<= 8'b10000000;
                       9: number8<= 8'b10010000;
                       
                       //对应数字在7段数码显示管的表示（十位数字）
                       
                    endcase
                    case(money_hasPayed%10)
                      0: number7<= 8'b11000000;
                      1: number7<= 8'b11111001;
                      2: number7<= 8'b10100100;
                      3: number7<= 8'b10110000;
                      4: number7<= 8'b10011001;
                      5: number7<= 8'b10010010; 
                      6: number7<= 8'b10000010;
                      7: number7<= 8'b11111000;
                      8: number7<= 8'b10000000;
                      9: number7<= 8'b10010000;
                    endcase
                    
                        //对应数字在7段数码显示管的表示（个位数字）
                    
                    case((60-secondCount)/10)
                    0: number2<= 8'b11000000;
                    1: number2<= 8'b11111001;
                    2: number2<= 8'b10100100;
                    3: number2<= 8'b10110000;
                    4: number2<= 8'b10011001;
                    5: number2<= 8'b10010010; 
                    6: number2<= 8'b10000010;
                    endcase
                    case((60-secondCount)%10)
                    0: number1<= 8'b11000000;
                    1: number1<= 8'b11111001;
                    2: number1<= 8'b10100100;
                    3: number1<= 8'b10110000;
                    4: number1<= 8'b10011001;
                    5: number1<= 8'b10010010; 
                    6: number1<= 8'b10000010;
                    7: number1<= 8'b11111000;
                    8: number1<= 8'b10000000;
                    9: number1<= 8'b10010000;
                    endcase
                    
                    //7段数码显示管显示时间
                    
                    if(money_shouldPay>=10)
                      begin
                      case (money_shouldPay/10)
                         0: number5<= 8'b11000000;
                         1: number5<= 8'b11111001;
                         2: number5<= 8'b10100100;
                         3: number5<= 8'b10110000;
                         4: number5<= 8'b10011001;
                         5: number5<= 8'b10010010; 
                         6: number5<= 8'b10000010;
                         7: number5<= 8'b11111000;
                         8: number5<= 8'b10000000;
                         9: number5<= 8'b10010000;
                         default: number5<= 8'b10000000;
                      endcase
                      case (money_shouldPay%10)
                          0: number4<= 8'b11000000;
                          1: number4<= 8'b11111001;
                          2: number4<= 8'b10100100;
                          3: number4<= 8'b10110000;
                          4: number4<= 8'b10011001;
                          5: number4<= 8'b10010010; 
                          6: number4<= 8'b10000010;
                          7: number4<= 8'b11111000;
                          8: number4<= 8'b10000000;
                          9: number4<= 8'b10010000;
                          default: number4<= 8'b10000000;
                       endcase
                      
                      end
                      
                      //7段数码显示管显示所需总金额
                      
                    else
                      begin
                      number5<=8'b11000000;
                      case(money_shouldPay)
                        0: number4<= 8'b11000000;
                        1: number4<= 8'b11111001;
                        2: number4<= 8'b10100100;
                        3: number4<= 8'b10110000;
                        4: number4<= 8'b10011001;
                        5: number4<= 8'b10010010; 
                        6: number4<= 8'b10000010;
                        7: number4<= 8'b11111000;
                        8: number4<= 8'b10000000;
                        9: number4<= 8'b10010000;
                        default: number4<= 8'b10000000;
                      endcase
                      end
                      
                      //总金额小于10的时候第一位变成0
                      
                    stage<=print1;
                    end
             end
             
           print1:
             begin//下面是7段数码显示管的分频器
             if(count==20000)
               begin
               count<=0;
               seg_en <= bright1;
               seg_out <= number1;
               stage<=print2;
               end
             else
               begin
               count<=count+1;
               end
             end
             
           print2:
             begin
             if(count==20000)
               begin
               count<=0;
               seg_en <= bright2;
               seg_out <= number2;
               stage<=print4;
               end
             else
               begin
               count<=count+1;
               end
             end
           print4:
             begin
             if(count==20000)
                begin
                count<=0;
                seg_en <= bright4;
                seg_out <= number4;
                stage <= print5;
                end
              else
                begin
                count <= count+1;
                end
             end
           print5:
             begin
             if(count==20000)
             begin
             count<=0;
             seg_en <= bright5;
             seg_out <= number5;
             stage <= print7;
             end
             else
             begin
             count <= count+1;
             end
             end
           print7:
             begin
             if(count==20000)
               begin
               count<=0;
               seg_en <= bright7;
               seg_out <= number7;
               stage <= print8;
               end
               else
               begin
               count<=count+1;
               end
               end
            print8:
            begin            
            if(count==20000)
            begin
            count<=0;
            seg_en <= bright8;
            seg_out <= number8;
            
            if(repayFlag)
              stage <= repay;
            else if(changeFlag)
              stage <= change;
            else
              stage <= 4'b0000;
            end
            
            else
            begin
                count<=count+1;
            end
            end
            
            repay:
              begin
              number1<=8'b11000000;
              number2<=8'b11000000;
              number4<=8'b11000000;
              number5<=8'b11000000;
              stage<=print1;
              end
              
              
            change:
              begin
              number1<= 8'b11000000;
              number2<= 8'b11000000;
              number4<= 8'b11000000;
              number5<= 8'b11000000;
              
              case((money_hasPayed-money_shouldPay)/10)
                0: number8<= 8'b11000000;
                1: number8<= 8'b11111001;
                2: number8<= 8'b10100100;
                3: number8<= 8'b10110000;
                4: number8<= 8'b10011001;
                5: number8<= 8'b10010010; 
                6: number8<= 8'b10000010;
                7: number8<= 8'b11111000;
                8: number8<= 8'b10000000;
                9: number8<= 8'b10010000;
              endcase
              case((money_hasPayed-money_shouldPay)%10)
                0: number7<= 8'b11000000;
                1: number7<= 8'b11111001;
                2: number7<= 8'b10100100;
                3: number7<= 8'b10110000;
                4: number7<= 8'b10011001;
                5: number7<= 8'b10010010; 
                6: number7<= 8'b10000010;
                7: number7<= 8'b11111000;
                8: number7<= 8'b10000000;
                9: number7<= 8'b10010000;
               endcase
               
               //7段数码显示管显示零钱
               
               stage<=print1;
              end
          endcase

        end//if(付款)结束
        
        ////admin
        2'b10:
        begin
             repayFlag<=0; changeFlag<=0;
             case (scan_cnta)
                   3'b000: begin seg_en <= 8'b01111111; seg_out<=digit1; end
                   3'b001: begin seg_en <= 8'b10111111; seg_out<=digit2; end
                   3'b010: begin seg_en <= 8'b11101111; seg_out<=digit4; end
                   3'b011: begin seg_en <= 8'b11110111; seg_out<=digit5; end
                   3'b100: begin seg_en <= 8'b11111101; seg_out<=digit7; end
                   3'b101: begin seg_en <= 8'b11111110; seg_out<=digit8; end
             endcase//分频器来控制7段数码显示管的使能
                            if(clear)
                                 begin
                                 left1 <= 0;
                                 left2 <= 0;
                                 left3 <= 0;
                                 end
                         case(mode)//是否清空，即管理员拿货
                         Search:begin//search阶段，即管理员查询模式
                               case(totalMoney_inMachine/10)
                                    0: digit1<= 8'b11000000;
                                    1: digit1<= 8'b11111001;
                                    2: digit1<= 8'b10100100;
                                    3: digit1<= 8'b10110000;
                                    4: digit1<= 8'b10011001;
                                    5: digit1<= 8'b10010010; 
                                    6: digit1<= 8'b10000010;
                                    7: digit1<= 8'b11111000;
                                    8: digit1<= 8'b10000000;
                                    9: digit1<= 8'b10010000;
                               endcase
                               case(totalMoney_inMachine%10)
                                   0: digit2<= 8'b11000000;
                                   1: digit2<= 8'b11111001;
                                   2: digit2<= 8'b10100100;
                                   3: digit2<= 8'b10110000;
                                   4: digit2<= 8'b10011001;
                                   5: digit2<= 8'b10010010; 
                                   6: digit2<= 8'b10000010;
                                   7: digit2<= 8'b11111000;
                                   8: digit2<= 8'b10000000;
                                   9: digit2<= 8'b10010000;
                               endcase//接下来决定哪一件商品被显示
                               if (selection[0]) begin
                                     digit4<=8'b10001000;
                                     digit7<=8'b11111111;
                                     case(sold_amount1)
                                           0: digit8<= 8'b11000000;
                                           1: digit8<= 8'b11111001;
                                           2: digit8<= 8'b10100100;
                                           3: digit8<= 8'b10110000;
                                           4: digit8<= 8'b10011001;
                                           5: digit8<= 8'b10010010; 
                                           6: digit8<= 8'b10000010;
                                           7: digit8<= 8'b11111000;
                                           8: digit8<= 8'b10000000;
                                           9: digit8<= 8'b10010000;
                                           10:begin digit7<=8'b11111001;
                                              digit8<=8'b11000000; end
                                           endcase
                                    
                               end
                               else if (selection[1]) begin
                                     digit4<=8'b10000011;
                                     digit7<=8'b11111111;
                                     case(sold_amount2)
                                           0: digit8<= 8'b11000000;
                                           1: digit8<= 8'b11111001;
                                           2: digit8<= 8'b10100100;
                                           3: digit8<= 8'b10110000;
                                           4: digit8<= 8'b10011001;
                                           5: digit8<= 8'b10010010; 
                                           6: digit8<= 8'b10000010;
                                           7: digit8<= 8'b11111000;
                                           8: digit8<= 8'b10000000;
                                           9: digit8<= 8'b10010000;
                                           10:begin digit7<=8'b11111001;
                                              digit8<=8'b11000000; end
                                           endcase
                                     
                               end
                               else if (selection[2]) begin
                                     digit4<=8'b11000110;
                                     digit7<=8'b11111111;
                                     case(sold_amount3)
                                           0: digit8<= 8'b11000000;
                                           1: digit8<= 8'b11111001;
                                           2: digit8<= 8'b10100100;
                                           3: digit8<= 8'b10110000;
                                           4: digit8<= 8'b10011001;
                                           5: digit8<= 8'b10010010; 
                                           6: digit8<= 8'b10000010;
                                           7: digit8<= 8'b11111000;
                                           8: digit8<= 8'b10000000;
                                           9: digit8<= 8'b10010000;
                                           10:begin digit7<=8'b11111001;
                                              digit8<=8'b11000000; end
                                           endcase
                                     
                               end
             
                               else begin
                                     digit4<=8'b11111111;
                                     digit7<=8'b11111111;
                                     digit8<=8'b11000000;
                               end
                             end
                         Add:begin digit4<=8'b11111111;//进入加货阶段
                               
                               if (add[0]&&(~temp[0])) 
                                     begin
                                     amountAdd<=amountAdd+1;
                                     temp[0]<=1;
                                     end
                               if (~add[0]) begin
                                     temp[0]<=0;  
                               end
                               if (amountAdd>=10) begin
                                     amountAdd<=0;
                                     end//同理买货的增加数量
                                                       
                                 case (amountAdd)
                                     0: digit2<= 8'b11000000;
                                     1: digit2<= 8'b11111001;
                                     2: digit2<= 8'b10100100;
                                     3: digit2<= 8'b10110000;
                                     4: digit2<= 8'b10011001;
                                     5: digit2<= 8'b10010010; 
                                     6: digit2<= 8'b10000010;
                                     7: digit2<= 8'b11111000;
                                     8: digit2<= 8'b10000000;
                                     9: digit2<= 8'b10010000;
                               endcase
                               
                               if (selection[0]) begin//决定哪一件商品加货
                                     digit4<=8'b10001000;
                                     digit7<=8'b11111111;
                                     addAble1=10-left1;
                                          case(addAble1)
                                           0: digit8<= 8'b11000000;
                                           1: digit8<= 8'b11111001;
                                           2: digit8<= 8'b10100100;
                                           3: digit8<= 8'b10110000;
                                           4: digit8<= 8'b10011001;
                                           5: digit8<= 8'b10010010; 
                                           6: digit8<= 8'b10000010;
                                           7: digit8<= 8'b11111000;
                                           8: digit8<= 8'b10000000;
                                           9: digit8<= 8'b10010000;
                                           10:begin digit7<=8'b11111001;
                                              digit8<=8'b11000000; end
                                           endcase
                                     
                                     if (add[1]&&(~temp[1])) begin
                                     left1<=left1+amountAdd;
                                     if (left1>10) begin
                                     left1<=10;
                                     end
                                     temp[1]<=1;
                               end
                                     if (~add[1]) begin
                                     temp[1]<=0;      
                                     end
                               end
                               else if (selection[1]) begin
                                     digit4<=8'b10000011;
                                     digit7<=8'b11111111;
                                     addAble2=10-left2;
                                          case(addAble2)
                                           0: digit8<= 8'b11000000;
                                           1: digit8<= 8'b11111001;
                                           2: digit8<= 8'b10100100;
                                           3: digit8<= 8'b10110000;
                                           4: digit8<= 8'b10011001;
                                           5: digit8<= 8'b10010010; 
                                           6: digit8<= 8'b10000010;
                                           7: digit8<= 8'b11111000;
                                           8: digit8<= 8'b10000000;
                                           9: digit8<= 8'b10010000;
                                           10:begin digit7<=8'b11111001;
                                              digit8<=8'b11000000; end
                                           endcase
                                     
                                     if (add[1]&&(~temp[1])) begin
                                     left2<=left2+amountAdd;
                                     if (left2>10) begin
                                     left2<=10;
                                     end
                                     temp[1]<=1;
                               end
                                     if (~add[1]) begin
                                     temp[1]<=0;      
                                     end
                               end
                               else if (selection[2]) begin
                                     digit4<=8'b11000110;
                                     digit7<=8'b11111111;
                                     addAble3<=10-left3;
                                          case(addAble3)
                                           0: digit8<= 8'b11000000;
                                           1: digit8<= 8'b11111001;
                                           2: digit8<= 8'b10100100;
                                           3: digit8<= 8'b10110000;
                                           4: digit8<= 8'b10011001;
                                           5: digit8<= 8'b10010010; 
                                           6: digit8<= 8'b10000010;
                                           7: digit8<= 8'b11111000;
                                           8: digit8<= 8'b10000000;
                                           9: digit8<= 8'b10010000;
                                           10:begin digit7<=8'b11111001;
                                              digit8<=8'b11000000; end
                                           endcase
                                     
                                     if (add[1]&&(~temp[1])) begin
                                     left3<=left3+amountAdd;
                                     if (left3>10) begin
                                     left3<=10;
                                     end
                                     temp[1]<=1;
                               end
                                     if (~add[1]) begin
                                     temp[1]<=0;      
                                     end
                               end
                               else begin
                                     digit1 <= 8'b11000000;
                                     digit4 <= 8'b11111111;
                                     digit7 <= 8'b11111111;
                                     digit8 <= 8'b11000000;
                                     amountAdd<=0;
                               end
                            end 
                    endcase             
             
        
        
        end
        ////admin
        
        2'b00://使能开关关闭
       
        begin//一切状态初始化
            sold_amount1 <= 0;
            sold_amount2 <= 0;
            sold_amount3 <= 0;
           
            adding1 <= 0;
            adding2 <= 0;
            adding3 <= 0;
            secondCount <= 0;
          	stage<=0;
          	repayFlag<=0;
         	changeFlag<=0;
          	seg_en <= bright0;
          	money_shouldPay <= 0;
          	money_hasPayed <= 0;//初始化，一切都是0
          	bit_select = 8'b0000_0000;
          	total_seg = 56'd0;
          	totalMoney_inMachine <= 0;
            amountAdd<=0;
            left1<=2;
            left2<=3;
            left3<=4; 
            digit1<=8'b11111111;
            digit2<=8'b11111111;
            digit4<=8'b11111111;
            digit5<=8'b11111111;
            digit7<=8'b11111111;
            digit8<=8'b11111111;
          end
        endcase
      end
endmodule
