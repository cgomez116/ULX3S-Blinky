##
## Simulation Rules
##
.PHONY: simulate
simulate: obj_dir/Vvgatestsrc
	obj_dir/Vvgatestsrc

obj_dir/Vvgatestsrc: ../hdmi_common/vgatestsrc.v vgatestsrc_tb.cpp
	verilator -GBITS_PER_COLOR=8 -cc --exe --trace --build -j \
		../hdmi_common/vgatestsrc.v vgatestsrc_tb.cpp

##
## ULX3S Rules
##
YOSYS=yosys
NEXTPNR=nextpnr-ecp5
ECPPACK=ecppack
HDMICODE=../hdmi_common/llhdmi.v ../hdmi_common/vgatestsrc.v
ENCODER=../hdmi_common/TMDS_encoder.v
SERIALIZER=../hdmi_common/tmds_serial.v

.PHONY: bitstream
bitstream: ulx3s.bit

ulx3s.bit: ulx3s.config
	$(ECPPACK) --input ulx3s.config \
		--bit ulx3s.bit

ULX3S.ys: ULX3S.v $(HDMICODE) $(ENCODER) $(SERIALIZER) \
		../hdmi_common/clock.v ../hdmi_common/OBUFDS.v
	chmod +x ysgen.sh
	./ysgen.sh ULX3S.v $(HDMICODE) $(ENCODER) $(SERIALIZER) \
		../hdmi_common/clock.v \
		../hdmi_common/OBUFDS.v > ULX3S.ys
	echo "hierarchy -top ULX3S" >> ULX3S.ys
	echo "synth_ecp5 -json ULX3S.json" >> ULX3S.ys

ULX3S.json: ULX3S.ys
	$(YOSYS) -q ULX3S.ys

ulx3s.config: ULX3S.json
	$(NEXTPNR) --85k --json ULX3S.json --lpf ulx3s_v20_segpdi.lpf \
		--package CABGA381 \
		--textcfg ulx3s.config

##
.PHONY: clean
clean:
	rm -rf obj_dir *.vcd
	rm -f image.ppm
	rm -f ULX3S.ys ULX3S.json ulx3s.config ulx3s.bit
