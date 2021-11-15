kagaya:
	php ../../utils/dither4.php kagaya.png out.bin
	php ../../utils/dither4.php kagaya.png out.png
	dd bs=1 if=out.bin seek=16384 of=temp.bin
	php ../../utils/bin2mif.php temp.bin 65536 > ../de0/zram.mif
	rm *.bin
