# Checklist lab — FPGA Snake, DE10-Standard, 2 giờ

## 1. Chuẩn bị trước khi bắt đầu tính giờ mượn kit

- [ ] Xác nhận kit là **DE10-Standard**, FPGA **5CSXFC6D6F31C6**; không phải DE10-Lite, DE10-Nano hay DE2.
- [ ] Đếm số bóng LED thực tế. Bản hiện tại dùng **60 LED**, rắn dài **5**. Khi chờ, chỉ bóng **56–60 tính từ DIN** sáng; thử một đoạn ngắn có thể thấy tối dù code vẫn chạy.
- [ ] Nếu cần đổi số LED: sửa `LED_COUNT` trong `rtl/top_snake_game.sv`, giữ chiều dài rắn 5 và số LED lớn hơn 5, mô phỏng lại phần liên quan rồi compile lại trước buổi lab.
- [ ] Mang laptop, nguồn riêng đúng loại của kit và cáp USB **A–B cho USB-Blaster II**. Cổng USB mini-B UART không dùng để nạp FPGA.
- [ ] Kiểm tra laptop đã có Quartus Prime Lite 23.1, hỗ trợ Cyclone V và driver USB-Blaster II. Kiểm tra nhận kit khi tới lab.
- [ ] Mang sạc Samsung **5 V–1,55 A**, dây nguồn USB, LM2596 có màn hình; chỉnh OUT khoảng **4,0 V** trước khi nối LED.
- [ ] Chuẩn bị đầu kẹp **strip-to-wire 3 chân** đúng bề rộng. Thử độ chắc và khả năng đóng nắp trên pad có thiếc trước; không cố ép.
- [ ] Chuẩn bị dây nguồn, đầu nối cách điện và jumper có **đầu cái** phù hợp header kit. Không kẹp cá sấu lớn trực tiếp vào ba pad sát nhau.
- [ ] Có thể mượn đồng hồ/oscilloscope ở lab nếu cần; màn hình LM2596 chỉ là phép kiểm tra điện áp sơ bộ tại module.
- [ ] Lưu cả project và bản `.sof` mới nhất ở máy, dùng được khi không có mạng.
- [ ] Hoàn tất mô phỏng trước lab. **Không cần chạy lại 4 TB module tại lab nếu mã đã kiểm tra không đổi.** Nếu sửa RTL, chạy test liên quan và top/output test trước khi compile/nạp lại.

## 2. File nào dùng làm gì?

| File | Vai trò | Nạp lên FPGA? |
| --- | --- | --- |
| `quartus/top_snake_game/top_snake_game.qpf` | Mở project Quartus | Không |
| `quartus/top_snake_game/top_snake_game.qsf` | Chọn chip, top, chân I/O, RTL, SDC và thư mục output | Không |
| `quartus/top_snake_game/top_snake_game.sdc` | Ràng buộc clock/timing, được Quartus đọc khi compile | **Không nạp riêng** |
| `rtl/*.sv` | Mã thiết kế, đầu vào của compiler | Không nạp trực tiếp |
| `quartus/top_snake_game/output_files/top_snake_game.sof` | Cấu hình FPGA đã compile | **Có — dùng file này** |
| Các file `.rpt`, `.summary`, `.pin` trong output | Báo cáo build, timing, chân thực tế | Không |
| `tb/*.sv`, các file `.do` | Mô phỏng trên máy tính | Không |

**SDC đi vào quá trình tạo SOF.** Sửa SDC xong phải compile lại; không thêm SDC vào Programmer. Nạp SOF qua JTAG là cấu hình tạm thời, mất khi kit mất nguồn; buổi lab này không cần ghi flash bằng POF/JIC.

### Nếu cần compile lại

1. Mở Quartus 23.1, **File → Open Project**, chọn QPF ở trên.
2. Kiểm tra device `5CSXFC6D6F31C6`, top `top_snake_game`.
3. Kiểm tra SDC đã nằm trong project; QSF có `SDC_FILE top_snake_game.sdc`.
4. **Processing → Start Compilation**. Chờ Full Compilation thành công; kiểm tra Timing Analyzer không có timing violation hay đường ra DIN bị bỏ ràng buộc.
5. Xác nhận thời gian tạo SOF mới tại **`output_files/top_snake_game.sof`**. Nếu compile lỗi, không lấy SOF còn sót của lần trước để coi là bản mới.

## 3. Quy trình hai tiếng

### Phút 0–15: kiểm tra kit, dây và nguồn

- [ ] Khi đang tắt nguồn, kiểm tra jumper **JP3 = 2,5 V** phù hợp cấu hình SW0 hiện tại. Nhờ người phụ trách lab xác nhận nếu jumper khác; không tự đổi khi kit đang có điện.
- [ ] Xác định đúng header GPIO và chân theo manual; `GPIO[0]` là tên tín hiệu, không phải số chân in trên mọi sơ đồ.
- [ ] Xác nhận ba pad đầu LED: `+5V`, `DIN`, `GND`; mũi tên dữ liệu đi từ DIN vào dải LED.
- [ ] Kiểm tra các đầu kim loại không chạm nhau, kẹp không tuột. **Ngắt nguồn trước khi đổi dây.**
- [ ] Đấu `LM2596 OUT+ → LED +5V`, `OUT− → LED GND`.
- [ ] Đấu thêm **GND kit → cùng GND LED/OUT−**. Dòng cấp LED đi thẳng về LM2596; không cấp LED từ GPIO.
- [ ] Khi mọi nguồn còn tắt, nối **GPIO[0] / PIN_W15 → DIN**; đặt **SW0 lên** để giữ reset sau khi nạp.
- [ ] Cấp nguồn LM2596/LED trước khi kit bắt đầu phát dữ liệu. Kiểm tra màn hình đang chọn **OUT**, khoảng 4,0 V; IN dự kiến gần 5 V.

### Phút 15–30: nạp SOF

1. Cấp nguồn riêng cho kit, bật kit; nối cáp USB vào cổng **USB-Blaster II**.
2. Trong Quartus, mở **Tools → Programmer**.
3. **Hardware Setup**: chọn USB-Blaster II của kit; chọn mode **JTAG**.
4. **Auto Detect**. Xác nhận FPGA Cyclone V tương ứng `5CSXFC6D6F31C6`. Nếu thấy thêm thiết bị HPS trong chain, giữ chain được nhận dạng; không gán SOF cho HPS.
5. Chọn đúng FPGA, dùng **Change File/Add File** theo trạng thái cửa sổ để gán duy nhất `output_files/top_snake_game.sof`; không tạo thêm bản sao FPGA trong chain.
6. Tick **Program/Configure** ở hàng FPGA, nhấn **Start**, chờ **100% Successful**.
7. Xác nhận **SW0 đang lên** để giữ reset (logic 1). Dây nguồn, GND và DIN đã nối ở bước trước; nếu phải đổi dây, tắt nguồn trước rồi nạp lại nếu kit đã mất nguồn.
8. Kiểm tra nguồn LED và GND chung đã sẵn sàng; gạt **SW0 xuống** (logic 0) để chạy.

> Có thể hoàn tất toàn bộ dây nối khi mọi nguồn đều tắt, rồi cấp nguồn LED trước khi FPGA bắt đầu phát dữ liệu. Tránh để DIN được lái HIGH khi LED chưa có nguồn. Khi mất nguồn kit phải nạp lại SOF.

### Phút 30–45: xác nhận frame chờ, chưa bấm KEY

- [ ] Với 60 LED, bóng **1–55 tắt**; bóng **56–60** lần lượt **đỏ, xanh lá, xanh dương, vàng, đỏ** tính từ đầu DIN.
- [ ] Mẫu đứng yên trong IDLE, không tự di chuyển khi chưa bấm KEY.
- [ ] Khi LED thực sự sáng, xem OUT có còn gần 4,0 V và IN có tụt rõ rệt không. Màn hình ổn không loại trừ mọi sụt áp nhanh hoặc sụt áp trên dây.
- [ ] Không thấy sáng chưa có nghĩa LED hỏng: xác minh số bóng, đầu DIN, reset, nguồn và GND trước.

### Phút 45–80: kiểm tra nút và gameplay

- [ ] Bấm một KEY bất kỳ để vào PLAYING. **Lần bấm đầu chỉ bắt đầu game**, không bắn đạn; nhả rồi bấm tiếp để bắn.
- [ ] KEY0 = đỏ; KEY1 = xanh lá; KEY2 = xanh dương; KEY3 = vàng. Không nhầm nút HPS với KEY0–KEY3 của FPGA.
- [ ] Đạn xuất hiện ở LED đầu DIN, đi một bóng mỗi **50 ms**; rắn đi về phía DIN mỗi **250 ms**.
- [ ] Đang có đạn thì bấm thêm không tạo đạn mới. Giữ nút không bắn liên tục; phải nhả rồi bấm lại.
- [ ] Bắn đúng màu đầu rắn: đạn mất, rắn ngắn đi một đốt. Bắn khác màu: đạn mất, chiều dài giữ nguyên.
- [ ] Nếu hết ván giữa chừng, reset SW0 lên rồi xuống để thử lại.

### Phút 80–100: kết thúc ván và kiểm tra tải lớn

- [ ] Để rắn tới đầu DIN: toàn dải đỏ, trạng thái LOSE giữ nguyên tới reset.
- [ ] Nếu thao tác kịp, bắn hết rắn: toàn dải xanh lá, trạng thái WIN giữ nguyên tới reset.
- [ ] Khi cả dải sáng, kiểm tra lại màn hình nguồn. Đây là tải cao hơn nhiều so với mẫu chờ 5 bóng.
- [ ] Reset sau WIN/LOSE: trở lại đúng mẫu chờ, không còn đạn cũ.
- [ ] Ghi kết quả WIN chưa thử được nếu thiếu thời gian; không đánh dấu đạt khi chưa quan sát.

### Phút 100–110: xử lý lỗi còn lại theo triệu chứng

| Triệu chứng | Thứ tự kiểm tra |
| --- | --- |
| Không thấy USB-Blaster | Nguồn kit → đúng cổng USB A–B → cáp → driver/Hardware Setup |
| Programmer báo sai device | Đúng DE10-Standard → Auto Detect → đúng hàng FPGA → đúng SOF trong output_files |
| Nạp thành công nhưng LED tối | SW0 lên rồi xuống → đúng số LED → nguồn LED → GND chung → đầu DIN → chân GPIO[0] |
| Màu sai hoặc nhấp nháy | Tiếp xúc kẹp → GND → dây DIN ngắn → nguồn khi có tải → đo waveform nếu có scope |
| Nút không phản ứng | Đúng KEY của FPGA → đã nhả nút → game chưa WIN/LOSE → không còn đạn đang bay |
| Chỉ lỗi khi cả dải sáng | Kiểm tra nguồn/cáp/kẹp dưới tải; không vội sửa logic game |

Nếu có oscilloscope: đo DIN so với **GND chung**, HIGH bit 0 khoảng **300 ns**, HIGH bit 1 khoảng **800 ns**, chu kỳ bit **1,1 µs**, khoảng LOW giữa frame **ít nhất 300 µs**. Đồng hồ DC không kiểm tra được các xung này.

Giới hạn mỗi hướng thử khoảng 10–15 phút. Thay một yếu tố mỗi lần và ghi kết quả. Nếu LM2596 không giữ được đầu ra dưới tải, nhờ lab hỗ trợ nguồn đầu vào phù hợp thông số module; vẫn chỉnh lại OUT trước khi nối LED.

### Phút 110–120: lưu kết quả và trả kit

- [ ] Chụp/quay mẫu chờ, điều khiển và WIN/LOSE đã kiểm tra được; lưu thông tin điện áp IN/OUT khi sáng.
- [ ] Ghi rõ file SOF đã dùng, các thay đổi nếu có, mục đạt/chưa đạt; giữ bản build tương ứng.
- [ ] Đưa hệ thống về reset, ngắt nguồn rồi tháo dây; tránh để kit tiếp tục phát DIN vào LED đã mất nguồn.
- [ ] Trả kit, nguồn và cáp đầy đủ.

## Tài liệu đối chiếu

- [Manual DE10-Standard của Terasic](https://www.mouser.com/datasheet/3/996/1/DE10-Standard_User_manual.pdf): JTAG, USB-Blaster II, chân FPGA, JP3 và header GPIO.
- Các giá trị timing, màu và hành vi nút ở checklist này lấy từ RTL của project; khả năng nhận mức DIN 3,3 V khi cấp LED 4,0 V cần được kiểm chứng trên dây thực tế theo phương án đã chốt.
