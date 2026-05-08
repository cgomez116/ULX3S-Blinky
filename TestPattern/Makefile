##
## Verilator Rules
##
.PHONY: all
all: image.ppm

image.ppm: obj_dir/Vpattern
	obj_dir/Vpattern > image.ppm

obj_dir/Vpattern: pattern.v pattern_tb.cpp
	verilator -cc --exe --trace --build -j \
		-CFLAGS "-I.." \
		-y ../hdmi_common \
		pattern.v pattern_tb.cpp

##
.PHONY: clean
clean:
	rm -rf obj_dir image.ppm *.vcd
	rm -f ULX3S_45F.ys ULX3S_45F.json ulx3s_45f_ULX3S_45F.config \
		ulx3s_45f_ULX3S_45F.bit

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
bitstream: ulx3s_45f_ULX3S_45F.bit

ulx3s_45f_ULX3S_45F.bit: ulx3s_45f_ULX3S_45F.config
	$(ECPPACK) --input ulx3s_45f_ULX3S_45F.config \
		--bit ulx3s_45f_ULX3S_45F.bit

ULX3S_45F.ys: ULX3S_45F.v $(HDMICODE) $(ENCODER) $(SERIALIZER) \
		../hdmi_common/clock.v ../hdmi_common/OBUFDS.v
	chmod +x ysgen.sh
	./ysgen.sh ULX3S_45F.v $(HDMICODE) $(ENCODER) $(SERIALIZER) \
		../hdmi_common/clock.v \
		../hdmi_common/OBUFDS.v > ULX3S_45F.ys
	echo "hierarchy -top ULX3S_45F" >> ULX3S_45F.ys
	echo "synth_ecp5 -json ULX3S_45F.json" >> ULX3S_45F.ys

ULX3S_45F.json: ULX3S_45F.ys
	$(YOSYS) -q ULX3S_45F.ys

ulx3s_45f_ULX3S_45F.config: ULX3S_45F.json
	$(NEXTPNR) --85k --json ULX3S_45F.json --lpf ulx3s_v20_segpdi.lpf \
		--package CABGA381 \
		--textcfg ulx3s_45f_ULX3S_45F.config
