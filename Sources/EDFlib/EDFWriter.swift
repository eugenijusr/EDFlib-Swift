//
//  EDFWriter.swift
//
//  Created by Fabrizio Caldarelli on 23/08/21.
//

/*
 *****************************************************************************
 *
 * Copyright (c) 2020 Teunis van Beelen
 * All rights reserved.
 *
 * Email: teuniz@protonmail.com
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the copyright holder nor the names of its
 *       contributors may be used to endorse or promote products derived from
 *       this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ''AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *****************************************************************************
 */

/**
 * EDF header. <br>
 * <br>
 *
 * <pre>
 * offset (hex, dec) length
 * ---------------------------------------------------------------------
 * 0x00      0     8 ascii : version of this data format (0)
 * 0x08      8    80 ascii : local patient identification
 * 0x58     88    80 ascii : local recording identification
 * 0xA8    168     8 ascii : startdate of recording (dd.mm.yy)
 * 0xB0    176     8 ascii : starttime of recording (hh.mm.ss)
 * 0xB8    184     8 ascii : number of bytes in header record
 * 0xC0    192    44 ascii : reserved
 * 0xEC    236     8 ascii : number of data records (-1 if unknown)
 * 0xF4    244     8 ascii : duration of a data record, in seconds
 * 0xFC    252     4 ascii : number of signals
 *
 *
 *
 *      0x00           0     ns * 16 ascii : ns * label (e.g. EEG Fpz-Cz or Body temp)
 * ns * 0x10    ns *  16     ns * 80 ascii : ns * transducer type (e.g. AgAgCl electrode)
 * ns * 0x60    ns *  96     ns *  8 ascii : ns * physical dimension (e.g. uV or degreeC)
 * ns * 0x68    ns * 104     ns *  8 ascii : ns * physical minimum (e.g. -500 or 34)
 * ns * 0x70    ns * 112     ns *  8 ascii : ns * physical maximum (e.g. 500 or 40)
 * ns * 0x78    ns * 120     ns *  8 ascii : ns * digital minimum (e.g. -2048)
 * ns * 0x80    ns * 128     ns *  8 ascii : ns * digital maximum (e.g. 2047)
 * ns * 0x88    ns * 136     ns * 80 ascii : ns * prefiltering (e.g. HP:0.1Hz LP:75Hz N:60)
 * ns * 0xD8    ns * 216     ns *  8 ascii : ns * nr of samples in each data record
 * ns * 0xE0    ns * 224     ns * 32 ascii : ns * reserved
 * </pre>
 *
 * <br>
 * ns: number of signals<br>
 * <br>
 * All fields are left aligned and filled up with spaces, no NULL's.<br>
 * <br>
 * Only printable ASCII characters are allowed.<br>
 * <br>
 * Decimal separator (if any) must be a dot. No grouping characters in
 * numbers.<br>
 * <br>
 * <br>
 * For more info about the EDF and EDF+ format, visit:
 * <a href="https://edfplus.info/specs/">https://edfplus.info/specs/</a><br>
 * <br>
 * For more info about the BDF and BDF+ format, visit: <a href=
 * "https://www.teuniz.net/edfbrowser/bdfplus%20format%20description.html">https://www.teuniz.net/edfbrowser/bdfplus%20format%20description.html</a><br>
 * <br>
 * <br>
 * note: In EDF, the sensitivity (e.g. uV/bit) and offset are stored using four
 * parameters:<br>
 * digital maximum and minimum, and physical maximum and minimum.<br>
 * Here, digital means the raw data coming from a sensor or ADC. Physical means
 * the units like uV.<br>
 * The sensitivity in units/bit is calculated as follows:<br>
 * <br>
 * units per bit = (physical max - physical min) / (digital max - digital
 * min)<br>
 * <br>
 * The digital offset is calculated as follows:<br>
 * <br>
 * offset = (physical max / units per bit) - digital max<br>
 * <br>
 * For a better explanation about the relation between digital data and physical
 * data,<br>
 * read the document "Coding Schemes Used with Data Converters" (PDF):<br>
 * <br>
 * <a href=
 * "https://www.ti.com/general/docs/lit/getliterature.tsp?baseLiteratureNumber=sbaa042">https://www.ti.com/general/docs/lit/getliterature.tsp?baseLiteratureNumber=sbaa042</a><br>
 * <br>
 * note: An EDF file usually contains multiple so-called datarecords. One
 * datarecord usually has a duration of one second (this is the default but it
 * is not mandatory!).<br>
 * In that case a file with a duration of five minutes contains 300 datarecords.
 * The duration of a datarecord can be freely choosen but, if possible, use
 * values from<br>
 * 0.1 to 1 second for easier handling. Just make sure that the total size of
 * one datarecord, expressed in bytes, does not exceed 10MByte (15MBytes for
 * BDF(+)).<br>
 * <br>
 * The RECOMMENDATION of a maximum datarecordsize of 61440 bytes in the EDF and
 * EDF+ specification was usefull in the time people were still using DOS as
 * their main operating system.<br>
 * Using DOS and fast (near) pointers (16-bit pointers), the maximum allocatable
 * block of memory was 64KByte.<br>
 * This is not a concern anymore so the maximum datarecord size now is limited
 * to 10MByte for EDF(+) and 15MByte for BDF(+). This helps to accommodate for
 * higher samplingrates<br>
 * used by modern Analog to Digital Converters.<br>
 * <br>
 * EDF header character encoding: The EDF specification says that only
 * (printable) ASCII characters are allowed.<br>
 * When writing the header info, EDFlib will assume you are using Latin1
 * encoding and it will automatically convert<br>
 * characters with accents, umlauts, tilde, etc. to their "normal" equivalent
 * without the accent/umlaut/tilde/etc.<br>
 * in order to create a valid EDF file.<br>
 * <br>
 * The description/name of an EDF+ annotation on the other hand, is encoded in
 * UTF-8.<br>
 * <br>
 *
 * @author Teunis van Beelen
 */

import Foundation

public class EDFWriter {

    public static let EDFLIB_TIME_DIMENSION : Int = 10000000
    public static let EDFLIB_MAXSIGNALS : Int = 640;

    /*
     * the following defines are used in the member "filetype" of the edf_hdr_struct
     */
    /* and as return value for the function edfopen_file_readonly() */
    public static let EDFLIB_FILETYPE_EDFPLUS : Int = 0;
    public static let EDFLIB_FILETYPE_BDFPLUS : Int = 1;
    public static let EDFLIB_NO_SUCH_FILE_OR_DIRECTORY : Int = -2;

    /*
     * when this error occurs, try to open the file with EDFbrowser, it will give
     * you full details about the cause of the error.
     */
    public static let EDFLIB_FILE_CONTAINS_FORMAT_ERRORS : Int = -3;

    public static let EDFLIB_FILE_WRITE_ERROR : Int = -8;
    public static let EDFLIB_NUMBER_OF_SIGNALS_INVALID : Int = -9;
    public static let EDFLIB_INVALID_ARGUMENT : Int = -12;
    public static let EDFLIB_TOO_MANY_DATARECORDS : Int = -13;

    /*
     * the following defines are possible errors returned by the first sample write
     * action
     */
    public static let EDFLIB_NO_SIGNALS : Int = -20;
    public static let EDFLIB_TOO_MANY_SIGNALS : Int = -21;
    public static let EDFLIB_NO_SAMPLES_IN_RECORD : Int = -22;
    public static let EDFLIB_DIGMIN_IS_DIGMAX : Int = -23;
    public static let EDFLIB_DIGMAX_LOWER_THAN_DIGMIN : Int = -24;
    public static let EDFLIB_PHYSMIN_IS_PHYSMAX : Int = -25;
    public static let EDFLIB_DATARECORD_SIZE_TOO_BIG : Int = -26;

    private final let EDFLIB_VERSION : Int = 101;

    /* max size of annotationtext */
    private final let EDFLIB_WRITE_MAX_ANNOTATION_LEN : Int = 40;

    /*
     * bytes in datarecord for EDF annotations, must be an integer multiple of three
     * and two
     */
    private final let EDFLIB_ANNOTATION_BYTES : Int = 114;

    /* for writing only */
    private final let EDFLIB_MAX_ANNOTATION_CHANNELS : Int = 64;

    private final let EDFLIB_ANNOT_MEMBLOCKSZ : Int = 1000;

    /* signal parameters */
    private var param_label : [String]!
    private var param_transducer : [String]!
    private var param_physdimension : [String]!
    private var param_phys_min : [Double]!
    private var param_phys_max : [Double]!
    private var param_dig_min : [Int]!
    private var param_dig_max : [Int]!
    private var param_prefilter : [String]!
    private var param_smp_per_record : [Int]!
    private var param_reserved : [String]!
    private var param_offset : [Double]!
    private var param_buf_offset : [Int]!
    private var param_bitvalue : [Double]!

    private var path : String!
    private var filetype : Int!
    private var plus_patientcode : String!
    private var plus_gender : Int!
    private var plus_birthdate_year : Int = 0
    private var plus_birthdate_month : Int!
    private var plus_birthdate_day : Int!
    private var plus_patient_name : String!
    private var plus_patient_additional : String!
    private var plus_admincode : String!
    private var plus_technician : String!
    private var plus_equipment : String!
    private var plus_recording_additional : String!
    private var l_starttime : Int!
    private var startdate_day : Int!
    private var startdate_month : Int!
    private var startdate_year : Int!
    private var starttime_second : Int!
    private var starttime_minute : Int!
    private var starttime_hour : Int!
    private var starttime_offset : Int!
    private var edfsignals : Int!
    private var datarecords : Int = 0
    private var recordsize : Int!
    private var annot_ch : [Int]!
    private var nr_annot_chns : Int!
    private var edf : Int = 0
    private var bdf : Int = 0
    private var signal_write_sequence_pos : Int = 0
    private var long_data_record_duration : Int!
    private var annots_in_file : Int!
    private var annotlist_sz : Int!
    private var total_annot_bytes : Int = 0
    private var eq_sf : Int!
    private var wrbuf : [Int8] = []
    private var wrbufsz : Int = 0
    private var hdr : [UInt8]?
    private var file_out : FileHandle!
    private var status_ok : Int = 0

    /**
     * This list contains the annotations (if any).
     */
    public var annotationslist : [EDFAnnotationStruct]

    /**
     * Creates an EDFWriter object that writes to an EDF+/BDF+ file. <br>
     * Warning: an already existing file with the same name will be silently
     * overwritten without advance warning.<br>
     *
     * @param p_path            The path to the file.
     *
     * @param f_filetype        Must be EDFLIB_FILETYPE_EDFPLUS (0) or
     *                          EDFLIB_FILETYPE_BDFPLUS (1).
     *
     * @param number_of_signals The number of signals you want to write into the
     *                          file.
     *
     * @throws IOException, EDFException
     */
    public init(p_path : String, f_filetype : Int, number_of_signals : Int) throws {

        annotationslist = [EDFAnnotationStruct]()

        path = p_path;

        nr_annot_chns = 1;

        long_data_record_duration = EDFWriter.EDFLIB_TIME_DIMENSION;

        annotlist_sz = 0;

        annots_in_file = 0;

        plus_gender = 2;

        edfsignals = number_of_signals;

        filetype = f_filetype;

        if ((edfsignals < 1) || (edfsignals > EDFWriter.EDFLIB_MAXSIGNALS)) {
            throw EDFException(err: EDFWriter.EDFLIB_NUMBER_OF_SIGNALS_INVALID, msg: "Invalid number of signals.\n");
        }

        if ((filetype != EDFWriter.EDFLIB_FILETYPE_EDFPLUS) && (filetype != EDFWriter.EDFLIB_FILETYPE_BDFPLUS)) {
            throw EDFException(err: EDFWriter.EDFLIB_NUMBER_OF_SIGNALS_INVALID, msg: "Invalid filetype.\n");
        }

        if (filetype == EDFWriter.EDFLIB_FILETYPE_EDFPLUS) {
            edf = 1;
        } else {
            bdf = 1;
        }

        file_out = FileHandle(forUpdatingAtPath: path)!

        file_out.truncateFile(atOffset: 0)

        annotationslist = [EDFAnnotationStruct]()

        param_label = [String](repeating: "", count: edfsignals)
        param_transducer = [String](repeating: "", count: edfsignals)
        param_physdimension = [String](repeating: "", count: edfsignals)
        param_phys_min = [Double](repeating: 0, count: edfsignals)
        param_phys_max = [Double](repeating: 0, count: edfsignals)
        param_dig_min = [Int](repeating: 0, count: edfsignals)
        param_dig_max = [Int](repeating: 0, count: edfsignals)
        param_prefilter = [String](repeating: "", count: edfsignals)
        param_smp_per_record = [Int](repeating: 0, count: edfsignals)
        param_offset = [Double](repeating: 0, count: edfsignals)
        param_buf_offset = [Int](repeating: 0, count: edfsignals)
        param_bitvalue = [Double](repeating: 0, count: edfsignals)

        status_ok = 1;
    }

    /**
     * If version is "1.00" than it will return 100.<br>
     *
     * @return version number of this library, multiplied by hundred.
     */
    public func version() -> Int {
        return EDFLIB_VERSION;
    }

    /**
     * Sets the samplefrequency of signal edfsignal. (In reallity, it sets the
     * number of samples in a datarecord.)<br>
     * The samplefrequency of a signal is determined as: fs = number of samples in a
     * datarecord / datarecord duration.<br>
     * The samplefrequency equals the number of samples in a datarecord only when
     * the datarecord duration is set to the default of one second.<br>
     * This function is required for every signal and can be called only before the
     * first sample write action.<br>
     *
     * @param edfsignal       signal number, zero based
     *
     * @param samplefrequency
     *
     * @return 0 on success, otherwise -1
     */
    public func setSampleFrequency(edfsignal : Int, samplefrequency : Int) -> Int {
        if ((edfsignal < 0) || (edfsignal >= edfsignals) || (samplefrequency < 1) || (datarecords != 0)) {
            return -1;
        }

        param_smp_per_record[edfsignal] = samplefrequency;

        return 0;
    }

    /**
     * Sets the maximum physical value of signal edfsignal. <br>
     * This is the value of the input of the ADC when the output equals the value of
     * "digital maximum".<br>
     * It is the highest value that the equipment is able to record. It does not
     * necessarily mean the signal recorded reaches this level.<br>
     * Must be un-equal to physical minimum.<br>
     * This function is required for every signal and can be called only before the
     * first sample write action.<br>
     *
     * note: In EDF, the sensitivity (e.g. uV/bit) and offset are stored using four
     * parameters:<br>
     * digital maximum and minimum, and physical maximum and minimum.<br>
     * Here, digital means the raw data coming from a sensor or ADC. Physical means
     * the units like uV.<br>
     * The sensitivity in units/bit is calculated as follows:<br>
     * <br>
     * units per bit = (physical max - physical min) / (digital max - digital
     * min)<br>
     * <br>
     * The digital offset is calculated as follows:<br>
     * <br>
     * offset = (physical max / units per bit) - digital max<br>
     *
     * @param edfsignal signal number, zero based
     *
     * @param phys_max
     *
     * @return 0 on success, otherwise -1
     */
    func setPhysicalMaximum(edfsignal : Int, phys_max : Double) -> Int {
        if ((edfsignal < 0) || (edfsignal >= edfsignals) || (datarecords != 0)) {
            return -1;
        }

        param_phys_max[edfsignal] = phys_max;

        return 0;
    }

    /**
     * Sets the minimum physical value of signal edfsignal. <br>
     * This is the value of the input of the ADC when the output equals the value of
     * "digital minimum".<br>
     * It is the lowest value that the equipment is able to record. It does not
     * necessarily mean the signal recorded reaches this level.<br>
     * Must be un-equal to physical maximum.<br>
     * This function is required for every signal and can be called only before the
     * first sample write action.<br>
     *
     * note: In EDF, the sensitivity (e.g. uV/bit) and offset are stored using four
     * parameters:<br>
     * digital maximum and minimum, and physical maximum and minimum.<br>
     * Here, digital means the raw data coming from a sensor or ADC. Physical means
     * the units like uV.<br>
     * The sensitivity in units/bit is calculated as follows:<br>
     * <br>
     * units per bit = (physical max - physical min) / (digital max - digital
     * min)<br>
     * <br>
     * The digital offset is calculated as follows:<br>
     * <br>
     * offset = (physical max / units per bit) - digital max<br>
     *
     * @param edfsignal signal number, zero based
     *
     * @param phys_min
     *
     * @return 0 on success, otherwise -1
     */
    func setPhysicalMinimum(edfsignal : Int, phys_min : Double) -> Int {
        if ((edfsignal < 0) || (edfsignal >= edfsignals) || (datarecords != 0)) {
            return -1;
        }

        param_phys_min[edfsignal] = phys_min;

        return 0;
    }

    /**
     * Sets the maximum digital value of signal edfsignal. The maximum value is
     * 32767 for EDF and 8388607 for BDF.<br>
     * It is the highest value that the equipment is able to record. It does not
     * necessarily mean the signal recorded reaches this level.<br>
     * Usually it's the extreme output of the ADC.<br>
     * Must be higher than digital minimum.<br>
     * This function is required for every signal and can be called only before the
     * first sample write action.<br>
     *
     * note: In EDF, the sensitivity (e.g. uV/bit) and offset are stored using four
     * parameters:<br>
     * digital maximum and minimum, and physical maximum and minimum.<br>
     * Here, digital means the raw data coming from a sensor or ADC. Physical means
     * the units like uV.<br>
     * The sensitivity in units/bit is calculated as follows:<br>
     * <br>
     * units per bit = (physical max - physical min) / (digital max - digital
     * min)<br>
     * <br>
     * The digital offset is calculated as follows:<br>
     * <br>
     * offset = (physical max / units per bit) - digital max<br>
     *
     * @param edfsignal signal number, zero based
     *
     * @param dig_max
     *
     * @return 0 on success, otherwise -1
     */
    func setDigitalMaximum(edfsignal : Int, dig_max : Int) -> Int {
        if ((edfsignal < 0) || (edfsignal >= edfsignals) || (datarecords != 0)) {
            return -1;
        }

        if (edf != 0) {
            if (dig_max > 32767) {
                return -1;
            }
        } else {
            if (dig_max > 8388607) {
                return -1;
            }
        }

        param_dig_max[edfsignal] = dig_max;

        return 0;
    }

    /**
     * Sets the minimum digital value of signal edfsignal. The minimum value is
     * -32768 for EDF and -8388608 for BDF.<br>
     * It is the lowest value that the equipment is able to record. It does not
     * necessarily mean the signal recorded reaches this level.<br>
     * Must be lower than digital maximum.<br>
     * Usually it's the extreme output of the ADC.<br>
     * This function is required for every signal and can be called only before the
     * first sample write action.<br>
     *
     * note: In EDF, the sensitivity (e.g. uV/bit) and offset are stored using four
     * parameters:<br>
     * digital maximum and minimum, and physical maximum and minimum.<br>
     * Here, digital means the raw data coming from a sensor or ADC. Physical means
     * the units like uV.<br>
     * The sensitivity in units/bit is calculated as follows:<br>
     * <br>
     * units per bit = (physical max - physical min) / (digital max - digital
     * min)<br>
     * <br>
     * The digital offset is calculated as follows:<br>
     * <br>
     * offset = (physical max / units per bit) - digital max<br>
     *
     * @param edfsignal signal number, zero based
     *
     * @param dig_min
     *
     * @return 0 on success, otherwise -1
     */
    func setDigitalMinimum(edfsignal : Int, dig_min : Int) -> Int {
        if ((edfsignal < 0) || (edfsignal >= edfsignals) || (datarecords != 0)) {
            return -1;
        }

        if (edf != 0) {
            if (dig_min < -32768) {
                return -1;
            }
        } else {
            if (dig_min < -8388608) {
                return -1;
            }
        }

        param_dig_min[edfsignal] = dig_min;

        return 0;
    }

    /**
     * Sets the label (name) of a signal. ("FP1", "SaO2", etc.)<br>
     * This function is recommended for every signal and can be called only before
     * the first sample write action.<br>
     *
     * @param edfsignal signal number, zero based
     *
     * @param label
     *
     * @return 0 on success, otherwise -1
     */
    public func setSignalLabel(edfsignal : Int, label : String) -> Int {
        if ((edfsignal < 0) || (edfsignal >= edfsignals) || (datarecords != 0)) {
            return -1;
        }

        param_label[edfsignal] = label;

        return 0;
    }

    /**
     * Sets the prefilter description of a signal. ("HP:0.05Hz", "LP:250Hz",
     * "N:60Hz", etc.)<br>
     * This function is optional and can be called only before the first sample
     * write action.<br>
     *
     * @param edfsignal signal number, zero based
     *
     * @param prefilter
     *
     * @return 0 on success, otherwise -1
     */
    public func setPreFilter(edfsignal : Int, prefilter : String) -> Int {
        if ((edfsignal < 0) || (edfsignal >= edfsignals) || (datarecords != 0)) {
            return -1;
        }

        param_prefilter[edfsignal] = prefilter;

        return 0;
    }

    /**
     * Sets the transducer description of a signal. ("AgAgCl cup electrodes",
     * etc.)<br>
     * This function is optional and can be called only before the first sample
     * write action.<br>
     *
     * @param edfsignal  signal number, zero based
     *
     * @param transducer
     *
     * @return 0 on success, otherwise -1
     */
    public func setTransducer(edfsignal : Int, transducer : String) -> Int {
        if ((edfsignal < 0) || (edfsignal >= edfsignals) || (datarecords != 0)) {
            return -1;
        }

        param_transducer[edfsignal] = transducer;

        return 0;
    }

    /**
     * Sets the physical_dimension (unit) of signal. ("uV", "BPM", "mA", "Degr.",
     * etc.)<br>
     * This function is recommended for every signal and can be called only before
     * the first sample write action.<br>
     *
     * @param edfsignal          signal number, zero based
     *
     * @param physical_dimension
     *
     * @return 0 on success, otherwise -1
     */
    public func setPhysicalDimension(edfsignal : Int, physical_dimension : String) -> Int {
        if ((edfsignal < 0) || (edfsignal >= edfsignals) || (datarecords != 0)) {
            return -1;
        }

        param_physdimension[edfsignal] = physical_dimension;

        return 0;
    }

    /**
     * Sets the startdate and starttime. <br>
     * If not called, the system date and time at runtime will be used.<br>
     * This function is optional and can be called only before the first sample
     * write action.<br>
     * Note: for anonymization purposes, the consensus is to use 1985-01-01 00:00:00
     * for the startdate and starttime.<br>
     * <br>
     * If subsecond precision is not needed or not applicable, leave it at zero.<br>
     *
     * @param year      1985 - 2084
     *
     * @param month     1 - 12
     *
     * @param day       1 - 31
     *
     * @param hour      0 - 23
     *
     * @param minute    0 - 59
     *
     * @param second    0 - 59
     *
     * @param subsecond 0 - 9999 expressed in units of 100 microSeconds
     *
     * @return 0 on success, otherwise -1
     */
    public func setStartDateTime(year : Int, month : Int, day : Int, hour : Int, minute : Int, second : Int, subsecond : Int) -> Int {
        if (datarecords != 0) {
            return -1;
        }

        if ((year < 1985) || (year > 2084) || (month < 1) || (month > 12) || (day < 1) || (day > 31) || (hour < 0)
                || (hour > 23) || (minute < 0) || (minute > 59) || (second < 0) || (second > 59) || (subsecond < 0)
                || (subsecond > 9999)) {
            return -1;
        }

        startdate_year = year;
        startdate_month = month;
        startdate_day = day;
        starttime_hour = hour;
        starttime_minute = minute;
        starttime_second = second;
        starttime_offset = subsecond * 1000;

        return 0;
    }

    /**
     * Sets the patientname. <br>
     * This function is optional and can be called only before the first sample
     * write action.<br>
     *
     * @param name
     *
     * @return 0 on success, otherwise -1
     */
    public func setPatientName(name : String) -> Int {
        if (datarecords != 0) {
            return -1;
        }

        plus_patient_name = name;

        return 0;
    }

    /**
     * Sets the patientcode. <br>
     * This function is optional and can be called only before the first sample
     * write action.<br>
     *
     * @param code
     *
     * @return 0 on success, otherwise -1
     */
    public func setPatientCode(code : String) -> Int {
        if (datarecords != 0) {
            return -1;
        }

        plus_patientcode = code;

        return 0;
    }


    /**
     * Sets the patients' gender. <br>
     * This function is optional and can be called only before the first sample
     * write action.<br>
     *
     * @param gender 0 = female, 1 = male, 2 = unknown or not applicable (this is
     *               the default)
     *
     * @return 0 on success, otherwise -1
     */
    public func setPatientGender(gender : Int) -> Int {
        if ((gender < 0) || (gender > 2) || (datarecords != 0)) {
            return -1;
        }

        plus_gender = gender;

        return 0;
    }

    /**
     * Sets the patients' birthdate. <br>
     * This function is optional and can be called only before the first sample
     * write action.<br>
     *
     * @param year  1800 - 3000
     *
     * @param month 1 - 12
     *
     * @param day   1 - 31
     *
     * @return 0 on success, otherwise -1
     */
    public func setPatientBirthDate(year : Int, month : Int, day : Int) -> Int {
        if (datarecords != 0) {
            return -1;
        }

        if ((year < 1800) || (year > 3000) || (month < 1) || (month > 12) || (day < 1) || (day > 31)) {
            return -1;
        }

        plus_birthdate_year = year;
        plus_birthdate_month = month;
        plus_birthdate_day = day;

        return 0;
    }

    /**
     * Sets the additional information related to the patient. <br>
     * This function is optional and can be called only before the first sample
     * write action.<br>
     *
     * @param additional
     *
     * @return 0 on success, otherwise -1
     */
    public func setPatientAdditional(additional : String) -> Int {
        if (datarecords != 0) {
            return -1;
        }

        plus_patient_additional = additional;

        return 0;
    }

    /**
     * Sets the administration code. <br>
     * This function is optional and can be called only before the first sample
     * write action.<br>
     *
     * @param admin_code
     *
     * @return 0 on success, otherwise -1
     */
    public func setAdministrationCode(admin_code : String) -> Int {
        if (datarecords != 0) {
            return -1;
        }

        plus_admincode = admin_code;

        return 0;
    }


    /**
     * Sets the name or id of the technician. <br>
     * This function is optional and can be called only before the first sample
     * write action.<br>
     *
     * @param technician
     *
     * @return 0 on success, otherwise -1
     */
    public func setTechnician(technician : String) -> Int {
        if (datarecords != 0) {
            return -1;
        }

        plus_technician = technician;

        return 0;
    }

    /**
     * Sets the description of the equipment used for the recording. <br>
     * This function is optional and can be called only before the first sample
     * write action.<br>
     *
     * @param equipment
     *
     * @return 0 on success, otherwise -1
     */
    public func setEquipment(equipment : String) -> Int {
        if (datarecords != 0) {
            return -1;
        }

        plus_equipment = equipment;

        return 0;
    }

    /**
     * Sets the additional info of the recording. <br>
     * This function is optional and can be called only before the first sample
     * write action.<br>
     *
     * @param additional
     *
     * @return 0 on success, otherwise -1
     */
    public func setAdditionalRecordingInfo(additional : String) -> Int {
        if (datarecords != 0) {
            return -1;
        }

        plus_recording_additional = additional;

        return 0;
    }

    private func buflen(_ str : [UInt8]) -> Int {
        for i in 0 ..< str.count {
            if (str[i] == 0) {
                return i;
            }
        }

        return str.count
    }

    private func bufcpy(dest : inout [UInt8], src : [UInt8]) -> Int {
        var sz = 0
        var srclen = 0

        sz = dest.count - 1;

        srclen = buflen(src);

        if (srclen > sz)
        {
            srclen = sz;
        }

        if (srclen < 0)
        {
            return 0;
        }

        for i in 0 ..< srclen {
            dest[i] = src[i];
        }

        dest[srclen] = 0;

        return srclen;
    }

    private func bufcat(dst : inout [UInt8], src : [UInt8]) -> Int {
        var sz = 0
        var srclen = 0
        var dstlen = 0

        dstlen = buflen(dst);

        sz = dst.count;

        sz -= dstlen + 1;

        if (sz <= 0)
        {
            return dstlen;
        }

        srclen = buflen(src);

        if (srclen > sz)
        {
            srclen = sz;
        }

        for i in 0 ..< srclen {
            dst[i + dstlen] = src[i];
        }

        dst[dstlen + srclen] = 0;

        return (dstlen + srclen);
    }

    private func latin1_to_ascii(str : inout [UInt8], len _len : Int) {
        var len = _len
        var value : UInt

        if (len > str.count) {
            len = str.count;
        }

        for i in 0 ..< len {
            value = UInt(str[i]);

            if (value < 0) {
                value += 256;
            }

            if ((value > 31) && (value < 127)) {
                continue;
            }

            switch (value) {
            case 128:
                str[i] = UInt8FromChar("E")
                break;

            case 130:
                str[i] = UInt8FromChar(",")
                break;

            case 131:
                str[i] = UInt8FromChar("F")
                break;

            case 132:
                str[i] = UInt8FromChar("\"")
                break;

            case 133:
                str[i] = UInt8FromChar(".")
                break;

            case 134:
                str[i] = UInt8FromChar("+")
                break;

            case 135:
                str[i] = UInt8FromChar("+")
                break;

            case 136:
                str[i] = UInt8FromChar("^")
                break;

            case 137:
                str[i] = UInt8FromChar("m")
                break;

            case 138:
                str[i] = UInt8FromChar("S")
                break;

            case 139:
                str[i] = UInt8FromChar("<")
                break;

            case 140:
                str[i] = UInt8FromChar("E")
                break;

            case 142:
                str[i] = UInt8FromChar("Z")
                break;

            case 145:
                str[i] = UInt8FromChar("`")
                break;

            case 146:
                str[i] = UInt8FromChar("\'")
                break;

            case 147:
                str[i] = UInt8FromChar("\"")
                break;

            case 148:
                str[i] = UInt8FromChar("\"")
                break;

            case 149:
                str[i] = UInt8FromChar(".")
                break;

            case 150:
                str[i] = UInt8FromChar("-")
                break;

            case 151:
                str[i] = UInt8FromChar("-")
                break;

            case 152:
                str[i] = UInt8FromChar("~")
                break;

            case 154:
                str[i] = UInt8FromChar("s")
                break;

            case 155:
                str[i] = UInt8FromChar(">")
                break;

            case 156:
                str[i] = UInt8FromChar("e")
                break;

            case 158:
                str[i] = UInt8FromChar("z")
                break;

            case 159:
                str[i] = UInt8FromChar("Y")
                break;

            case 171:
                str[i] = UInt8FromChar("<")
                break;

            case 180:
                str[i] = UInt8FromChar("\'")
                break;

            case 181:
                str[i] = UInt8FromChar("u")
                break;

            case 187:
                str[i] = UInt8FromChar(">")
                break;

            case 191:
                str[i] = UInt8FromChar("?")
                break;

            case 192:
                str[i] = UInt8FromChar("A")
                break;

            case 193:
                str[i] = UInt8FromChar("A")
                break;

            case 194:
                str[i] = UInt8FromChar("A")
                break;

            case 195:
                str[i] = UInt8FromChar("A")
                break;

            case 196:
                str[i] = UInt8FromChar("A")
                break;

            case 197:
                str[i] = UInt8FromChar("A")
                break;

            case 198:
                str[i] = UInt8FromChar("E")
                break;

            case 199:
                str[i] = UInt8FromChar("C")
                break;

            case 200:
                str[i] = UInt8FromChar("E")
                break;

            case 201:
                str[i] = UInt8FromChar("E")
                break;

            case 202:
                str[i] = UInt8FromChar("E")
                break;

            case 203:
                str[i] = UInt8FromChar("E")
                break;

            case 204:
                str[i] = UInt8FromChar("I")
                break;

            case 205:
                str[i] = UInt8FromChar("I")
                break;

            case 206:
                str[i] = UInt8FromChar("I")
                break;

            case 207:
                str[i] = UInt8FromChar("I")
                break;

            case 208:
                str[i] = UInt8FromChar("D")
                break;

            case 209:
                str[i] = UInt8FromChar("N")
                break;

            case 210:
                str[i] = UInt8FromChar("O")
                break;

            case 211:
                str[i] = UInt8FromChar("O")
                break;

            case 212:
                str[i] = UInt8FromChar("O")
                break;

            case 213:
                str[i] = UInt8FromChar("O")
                break;

            case 214:
                str[i] = UInt8FromChar("O")
                break;

            case 215:
                str[i] = UInt8FromChar("x")
                break;

            case 216:
                str[i] = UInt8FromChar("O")
                break;

            case 217:
                str[i] = UInt8FromChar("U")
                break;

            case 218:
                str[i] = UInt8FromChar("U")
                break;

            case 219:
                str[i] = UInt8FromChar("U")
                break;

            case 220:
                str[i] = UInt8FromChar("U")
                break;

            case 221:
                str[i] = UInt8FromChar("Y")
                break;

            case 222:
                str[i] = UInt8FromChar("I")
                break;

            case 223:
                str[i] = UInt8FromChar("s")
                break;

            case 224:
                str[i] = UInt8FromChar("a")
                break;

            case 225:
                str[i] = UInt8FromChar("a")
                break;

            case 226:
                str[i] = UInt8FromChar("a")
                break;

            case 227:
                str[i] = UInt8FromChar("a")
                break;

            case 228:
                str[i] = UInt8FromChar("a")
                break;

            case 229:
                str[i] = UInt8FromChar("a")
                break;

            case 230:
                str[i] = UInt8FromChar("e")
                break;

            case 231:
                str[i] = UInt8FromChar("c")
                break;

            case 232:
                str[i] = UInt8FromChar("e")
                break;

            case 233:
                str[i] = UInt8FromChar("e")
                break;

            case 234:
                str[i] = UInt8FromChar("e")
                break;

            case 235:
                str[i] = UInt8FromChar("e")
                break;

            case 236:
                str[i] = UInt8FromChar("i")
                break;

            case 237:
                str[i] = UInt8FromChar("i")
                break;

            case 238:
                str[i] = UInt8FromChar("i")
                break;

            case 239:
                str[i] = UInt8FromChar("i")
                break;

            case 240:
                str[i] = UInt8FromChar("d")
                break;

            case 241:
                str[i] = UInt8FromChar("n")
                break;

            case 242:
                str[i] = UInt8FromChar("o")
                break;

            case 243:
                str[i] = UInt8FromChar("o")
                break;

            case 244:
                str[i] = UInt8FromChar("o")
                break;

            case 245:
                str[i] = UInt8FromChar("o")
                break;

            case 246:
                str[i] = UInt8FromChar("o")
                break;

            case 247:
                str[i] = UInt8FromChar("-")
                break;

            case 248:
                str[i] = UInt8FromChar("0")
                break;

            case 249:
                str[i] = UInt8FromChar("u")
                break;

            case 250:
                str[i] = UInt8FromChar("u")
                break;

            case 251:
                str[i] = UInt8FromChar("u")
                break;

            case 252:
                str[i] = UInt8FromChar("u")
                break;

            case 253:
                str[i] = UInt8FromChar("y")
                break;

            case 254:
                str[i] = UInt8FromChar("t")
                break;

            case 255:
                str[i] = UInt8FromChar("y")
                break;

            default:
                str[i] = UInt8FromChar(" ")
                break;
            }
        }
    }

    func UInt8FromChar(_ ch : Character) -> UInt8
    {
        if let n = ch.utf8.first
        {
            return n
        }
        return 0
    }

    private func writeStringToFile(_ file : FileHandle, _ s : String) {
        file.write(s.data(using: .utf8)!)
    }

    /*
     * minimum is the minimum digits that will be printed (minus sign not included),
     * leading zero's will be added if necessary
     */
    /* if sign is zero, only negative numbers will have the sign '-' character */
    /* if sign is one, the sign '+' or '-' character will always be printed */
    /* returns the amount of characters printed */
    private func fprint_int_number_nonlocalized(file : FileHandle, q _q : Int, minimum _minimum : Int, sign : Int) -> Int {
        var flag = 0
        var z = 0
        var j = 0
        var base = 1000000000
        var minimum = _minimum
        var q = _q

        if (minimum < 0) {
            minimum = 0;
        }

        if (minimum > 9) {
            flag = 1;
        }

        if (q < 0) {
            writeStringToFile(file, "-")

            j += 1

            base = -base;
        } else {
            if (sign != 0) {
                writeStringToFile(file, "+")

                j += 1
            }
        }

        for i in (1 ... 10).reversed() {
            if (minimum == i) {
                flag = 1;
            }

            z = q / base;

            q %= base;

            if ((z != 0) || (flag != 0)) {
                file.write(Data([UInt8(48 + z)]))

                j += 1

                flag = 1;
            }

            base /= 10;
        }

        if (flag == 0) {
            writeStringToFile(file, "0")

            j += 1
        }

        return j;
    }

    /*
     * minimum is the minimum digits that will be printed (minus sign not included),
     * leading zero's will be added if necessary
     */
    /* if sign is zero, only negative numbers will have the sign '-' character */
    /* if sign is one, the sign '+' or '-' character will always be printed */
    /* returns the amount of characters printed */
    private func fprint_ll_number_nonlocalized(file : FileHandle, q _q : Int, minimum _minimum : Int, sign : Int) -> Int {
        var flag = 0
        var z : Int
        var i = 0
        var j = 0
        var base = 1000000000000000000
        var minimum = _minimum
        var q = _q

        if (minimum < 0) {
            minimum = 0;
        }

        if (minimum > 18) {
            flag = 1;
        }

        if (q < 0) {
            writeStringToFile(file, "-")

            j += 1

            base = -base;
        } else {
            if (sign != 0) {
                writeStringToFile(file, "+")

                j += 1
            }
        }

        for i in (1 ... 19).reversed() {
            if (minimum == i) {
                flag = 1;
            }

            z = (q / base);

            q %= base;

            if ((z != 0) || (flag != 0)) {
                writeStringToFile(file, "0\(z)")

                j += 1

                flag = 1;
            }

            base /= 10;
        }

        if (flag == 0) {
            writeStringToFile(file, "0")

            j += 1
        }

        return j;
    }

    /**
     * Sets the datarecord duration. <br>
     * This function is optional, normally you don't need to change the default
     * value of one second.<br>
     * This function is NOT REQUIRED but can be called only before the first sample
     * write action.<br>
     * <br>
     * This function can be used when you want to use a non-integer samplerate.<br>
     * For example, if you want to use a samplerate of 0.5 Hz, set the
     * samplefrequency to 5 Hz and<br>
     * the datarecord duration to 10 seconds, or alternatively, set the
     * samplefrequency to 1 Hz and<br>
     * the datarecord duration to 2 seconds.<br>
     * This function can also be used when you want to use a very high
     * samplerate.<br>
     * For example, if you want to use a samplerate of 5 GHz,<br>
     * set the samplefrequency to 5000 Hz and the datarecord duration to 1
     * microSecond.<br>
     * Do not use this function if not necessary.<br>
     *
     * @param duration expressed in microSeconds, range: 1 - 60000000 (1uSec. - 60
     *                 sec.)
     *
     * @return 0 on success, otherwise -1
     */
    public func setDataRecordDuration(duration : Int) -> Int {
        if ((duration < 1) || (duration > 60000000) || (datarecords != 0)) {
            return -1;
        }

        long_data_record_duration = duration * 10;

        return 0;
    }

    /**
     * Sets the number of annotation signals. The default value is 1<br>
     * This function is optional and, if used, must be called before the first
     * sample write action.<br>
     * Normally you don't need to change the default value. Only when the number of
     * annotations<br>
     * you want to write is higher than the number of datarecords in the recording,
     * you can use<br>
     * this function to increase the storage space for annotations.<br>
     *
     * @param annot_signals minimum is 1, maximum is 64
     *
     * @return 0 on success, otherwise -1
     */
    public func setNumberOfAnnotationSignals(annot_signals : Int) -> Int {
        if ((annot_signals < 1) || (annot_signals >= EDFLIB_MAX_ANNOTATION_CHANNELS) || (datarecords != 0)) {
            return -1;
        }

        nr_annot_chns = annot_signals;

        return 0;
    }

    private func sprint_number_nonlocalized(dest : inout [UInt8], val : Double) -> Int {
        var flag = 0
        var z = 0
        var j = 0
        var q : Int
        var base = 1000000000
        var sz = 0

        var _var : Double;

        sz = dest.count;

        if (sz < 1)
        {
            return 0;
        }

        q = Int(val);

        _var = val - Double(q);

        if (val < 0.0) {
            dest[j] = UInt8FromChar("-")
            j += 1

            if (q < 0) {
                base = -base;
            }
        }

        if (j == sz) {
            j -= 1
            dest[j] = 0;

            return j;
        }

        for i in (1...10).reversed() {
            z = q / base;

            q %= base;

            if ((z != 0) || (flag != 0)) {
                dest[j] = UInt8(48 + z)
                j += 1

                if (j == sz) {
                    j -= 1
                    dest[j] = 0;

                    return j;
                }

                flag = 1;
            }

            base /= 10;
        }

        if (flag == 0) {
            dest[j] = UInt8FromChar("0")
            j += 1
        }

        if (j == sz) {
            j -= 1
            dest[j] = 0;

            return j;
        }

        base = 100000000;

        _var *= Double((base * 10));

        q = Int(_var);

        if (q < 0) {
            base = -base;
        }

        if (q == 0) {
            dest[j] = 0;

            return j;
        }

        dest[j] = UInt8FromChar(".")
        j += 1

        if (j == sz) {
            j -= 1
            dest[j] = 0;

            return j;
        }


        for i in (1...9).reversed() {
            z = q / base;

            q %= base;

            dest[j] = UInt8(48 + z)
            j += 1

            if (j == sz) {
                j -= 1
                dest[j] = 0;

                return j;
            }

            base /= 10;
        }

        dest[j] = 0;

        j -= 1

        repeat
        {
            if (dest[j] == UInt8FromChar("0")) {
                dest[j] = 0;
            } else {
                j += 1

                break;
            }
            j -= 1
        } while(j > 0)


        return j;
    }

    /*
     * minimum is the minimum digits that will be printed (minus sign not included),
     * leading zero's will be added if necessary
     */
    /* if sign is zero, only negative numbers will have the sign '-' character */
    /* if sign is one, the sign '+' or '-' character will always be printed */
    /* returns the number of characters printed */
    private func snprint_ll_number_nonlocalized(dest : inout [UInt8], offset : Int, q _q : Int, minimum _minimum : Int, sign : Int) -> Int {
        var flag = 0
        var z : Int
        var j = offset
        var sz = 0
        var minimum = _minimum
        var q = _q

        var base = 1000000000000000000

        sz = dest.count

        if ((sz - offset) < 1) {
            return 0;
        }

        if (minimum < 0) {
            minimum = 0;
        }

        if (minimum > 18) {
            flag = 1;
        }

        if (q < 0) {
            dest[j] = UInt8FromChar("-")
            j += 1

            base = -base;
        } else {
            if (sign != 0) {
                dest[j] = UInt8FromChar("+")
                j += 1
            }
        }

        if (j == sz) {
            j -= 1
            dest[j] = 0;

            return (j - offset);
        }

        for i in (1...19).reversed() {
            if (minimum == i) {
                flag = 1;
            }

            z =  (q / base);

            q %= base;

            if ((z != 0) || (flag != 0)) {
                dest[j] = UInt8(48 + z)
                j += 1

                if (j == sz) {
                    j -= 1
                    dest[j] = 0;

                    return (j - offset);
                }

                flag = 1;
            }

            base /= 10;
        }

        if (flag == 0) {
            dest[j] = UInt8FromChar("0")
            j += 1
        }

        if (j == sz) {
            j -= 1
            dest[j] = 0;

            return (j - offset);
        }

        dest[j] = 0;

        return (j - offset);
    }

    /**
     * Writes an annotation/event to the file. <br>
     * onset is relative to the starttime of the recording.<br>
     * onset and duration are in units of 100 microSeconds. Resolution is 0.0001
     * second.<br>
     * E.g. 34.071 seconds must be written as 340710.<br>
     * If duration is unknown or not applicable: set a negative number (-1).<br>
     * Description is a string containing the text that describes the event.<br>
     * This function is optional.<br>
     *
     * @param onset       onset time of the event expressed in units of 100
     *                    microSeconds, must be >= 0
     *
     * @param duration    duration time of the event expressed in units of 100
     *                    microSeconds
     *
     * @param description description of the event
     *
     * @return 0 on success, otherwise -1
     */
    public func writeAnnotation(onset : Int, duration : Int, description : String) -> Int {
        var new_annotation : EDFAnnotationStruct

        if (status_ok == 0)
        {
            return -1;
        }

        if (onset < 0) {
            return -1;
        }

        if (annots_in_file >= annotlist_sz) {
            annotlist_sz += EDFLIB_ANNOT_MEMBLOCKSZ;

            // annotationslist.ensureCapacity(annotlist_sz);
        }

        new_annotation = EDFAnnotationStruct();

        new_annotation.onset = onset;

        new_annotation.duration = duration;

        new_annotation.description = description;

        annots_in_file += 1

        annotationslist.append(new_annotation)

        return 0;
    }

    private func write_tal(file : FileHandle) -> Int {
        var p = 0

        var str = [UInt8](repeating: 0, count: total_annot_bytes)

        p = snprint_ll_number_nonlocalized(dest: &str, offset: 0,
                                           q: (datarecords * long_data_record_duration + starttime_offset) / EDFWriter.EDFLIB_TIME_DIMENSION, minimum: 0, sign: 1);
        if (((long_data_record_duration % EDFWriter.EDFLIB_TIME_DIMENSION) != 0) || (starttime_offset != 0)) {
            str[p] = UInt8FromChar(".")
            p += 1
            p += snprint_ll_number_nonlocalized(dest: &str, offset: p,
                                                q: (datarecords * long_data_record_duration + starttime_offset) % EDFWriter.EDFLIB_TIME_DIMENSION, minimum: 7, sign: 0);
        }
        str[p] = 20;
        p += 1
        str[p] = 20;
        p += 1

        repeat
        {
            str[p] = 0
            p += 1
        } while (p < total_annot_bytes)


        file.write(Data(bytes: str, count: str.count))

        return 0;
    }

    /**
     * Finalizes and closes the file. <br>
     * This function is required after writing. Failing to do so will cause a
     * corrupted and incomplete file.<br>
     *
     * @throws IOException, EDFException
     *
     * @return 0 on success, otherwise -1
     */
    public func close() throws -> Int {
        if (status_ok == 0)
        {
            return -1;
        }

        if (datarecords < 100000000) {
            file_out.seek(toFileOffset: 236)
            if (fprint_int_number_nonlocalized(file: file_out, q: datarecords, minimum: 0, sign: 0) < 2) {
                writeStringToFile(file_out, " ")
            }
        } else {
            throw EDFException(err: EDFWriter.EDFLIB_TOO_MANY_DATARECORDS, msg: "Too many datarecords written.\n");
        }

        write_annotations()

        file_out.closeFile()

        status_ok = 0;

        return 0;
    }

    private func write_annotations() -> Int {
        var j = 0
        var n = 0
        var p = 0
        var datrecsize = 0

        var offset = 0
        var datrecs = 0
        var file_sz = 0

        var str = [UInt8](repeating: 0, count: EDFLIB_ANNOTATION_BYTES * 2)
        var str2 = [UInt8](repeating: 0, count: EDFLIB_ANNOTATION_BYTES)

        var annot2 : EDFAnnotationStruct

        offset = (edfsignals + nr_annot_chns + 1) * 256;

        file_sz = offset + (datarecords * recordsize);

        datrecsize = total_annot_bytes;

        for i in 0 ..< edfsignals {
            if (edf != 0) {
                offset += param_smp_per_record[i] * 2;

                datrecsize += param_smp_per_record[i] * 2;
            } else {
                offset += param_smp_per_record[i] * 3;

                datrecsize += param_smp_per_record[i] * 3;
            }
        }

        j = 0
        for k in 0 ..< annots_in_file {
            annot2 = annotationslist[k]

            annot2.onset += starttime_offset / 1000;

            p = 0;

            if (j == 0) // first annotation signal
            {
                if ((offset + total_annot_bytes) > file_sz) {
                    break;
                }

                file_out.seek(toFileOffset: UInt64(offset))

                p += snprint_ll_number_nonlocalized(dest: &str, offset: 0,
                                                    q: (datrecs * long_data_record_duration + starttime_offset) / EDFWriter.EDFLIB_TIME_DIMENSION, minimum: 0, sign: 1);

                if (((long_data_record_duration % EDFWriter.EDFLIB_TIME_DIMENSION) != 0) || (starttime_offset != 0)) {
                    str[p] = UInt8FromChar(".")
                    p += 1
                    n = snprint_ll_number_nonlocalized(dest: &str, offset: p,
                                                       q: (datrecs * long_data_record_duration + starttime_offset) % EDFWriter.EDFLIB_TIME_DIMENSION, minimum: 7, sign: 0);
                    p += n;
                }
                str[p] = 20;
                p += 1
                str[p] = 20;
                p += 1
                str[p] = 0;
                p += 1
            }

            n = snprint_ll_number_nonlocalized(dest: &str, offset: p, q: annot2.onset / 10000, minimum: 0, sign: 1);
            p += n;
            if ((annot2.onset % 10000) != 0) {
                str[p] = UInt8FromChar(".")
                p += 1
                n = snprint_ll_number_nonlocalized(dest: &str, offset: p, q: annot2.onset % 10000, minimum: 4, sign: 0);
                p += n;
            }
            if (annot2.duration >= 0) {
                str[p] = 21;
                p += 1
                n = snprint_ll_number_nonlocalized(dest: &str, offset: p, q: annot2.duration / 10000, minimum: 0, sign: 0);
                p += n;
                if ((annot2.duration % 10000) != 0) {
                    str[p] = UInt8FromChar(".")
                    p += 1
                    n = snprint_ll_number_nonlocalized(dest: &str, offset: p, q: annot2.duration % 10000, minimum: 4, sign: 0);
                    p += n;
                }
            }
            str[p] = 20;
            p += 1
            bufcpy(dest: &str2, src: Array(annot2.description.utf8));
            for i in 0 ..< EDFLIB_WRITE_MAX_ANNOTATION_LEN {
                if (str2[i] == 0) {
                    break;
                }

                str[p] = str2[i];
                p += 1
            }
            str[p] = 20
            p += 1

            repeat
            {
                str[p] = 0;
                p += 1
            } while (p < EDFLIB_ANNOTATION_BYTES)


            file_out.write(Data(bytes: str, count: EDFLIB_ANNOTATION_BYTES))

            j += 1

            if (j >= nr_annot_chns) {
                j = 0;

                offset += datrecsize;

                datrecs += 1

                if (datrecs >= datarecords) {
                    break;
                }
            }
        }

        return 0;
    }


    private func write_edf_header() -> Int {
        var i = 0
        var j = 0
        var p = 0
        var q = 0
        var len = 0
        var rest = 0

        var str = [UInt8](repeating: 0, count: 128)

        if (status_ok == 0)
        {
            return -1;
        }

        eq_sf = 1

        recordsize = 0;

        total_annot_bytes = EDFLIB_ANNOTATION_BYTES * nr_annot_chns

        for i in 0 ..< edfsignals {

            if (param_smp_per_record[i] < 1) {
                return EDFWriter.EDFLIB_NO_SAMPLES_IN_RECORD;
            }

            if (param_dig_max[i] == param_dig_min[i]) {
                return EDFWriter.EDFLIB_DIGMIN_IS_DIGMAX;
            }

            if (param_dig_max[i] < param_dig_min[i]) {
                return EDFWriter.EDFLIB_DIGMAX_LOWER_THAN_DIGMIN;
            }

            if (param_phys_max[i] == param_phys_min[i]) {
                return EDFWriter.EDFLIB_PHYSMIN_IS_PHYSMAX;
            }

            recordsize += param_smp_per_record[i];

            if (i > 0) {
                if (param_smp_per_record[i] != param_smp_per_record[i - 1]) {
                    eq_sf = 0;
                }
            }
        }

        if (edf != 0) {
            recordsize *= 2;

            recordsize += total_annot_bytes;

            if (recordsize > (10 * 1024 * 1024)) /* datarecord size should not exceed 10MB for EDF */
            {
                return EDFWriter.EDFLIB_DATARECORD_SIZE_TOO_BIG;
            } /*
             * if your application gets hit by this limitation, lower the value for the
             * datarecord duration
             */
            /* using the function edf_set_datarecord_duration() */
        } else {
            recordsize *= 3;

            recordsize += total_annot_bytes;

            if (recordsize > (15 * 1024 * 1024)) /* datarecord size should not exceed 15MB for BDF */
            {
                return EDFWriter.EDFLIB_DATARECORD_SIZE_TOO_BIG;
            } /*
             * if your application gets hit by this limitation, lower the value for the
             * datarecord duration
             */
            /* using the function edf_set_datarecord_duration() */
        }

        for i in 0 ..< edfsignals {
            param_bitvalue[i] = (param_phys_max[i] - param_phys_min[i]) / Double((param_dig_max[i] - param_dig_min[i]));
            param_offset[i] = param_phys_max[i] / param_bitvalue[i] - Double(param_dig_max[i]);
        }

        file_out.seek(toFileOffset: 0)

        if (edf != 0) {
            writeStringToFile(file_out, "0       ")
        } else {
            // -1
            file_out.write(Data([255]))
            writeStringToFile(file_out, "BIOSEMI")
        }

        p = 0;

        if (plus_birthdate_year == 0) {
            rest = 72;
        } else {
            rest = 62;
        }

        if (plus_patientcode != nil) {
            len = plus_patientcode!.count
        } else {
            len = 0;
        }
        if ((len != 0) && (rest != 0)) {
            if (len > rest) {
                len = rest;
                rest = 0;
            } else {
                rest -= len;
            }
            bufcpy(dest: &str, src: Array(plus_patientcode!.utf8))
            latin1_to_ascii(str: &str, len: len);
            for i in 0 ..< len {
                if (str[i] == UInt8FromChar(" ")) {
                    str[i] = UInt8FromChar(" ")
                }
            }
            file_out.write(Data(bytes: str, count: len))
            p += len;
            writeStringToFile(file_out, " ")
            p += 1
        } else {
            writeStringToFile(file_out, "X ")
            p += 2;
        }

        if (plus_gender == 1) {
            writeStringToFile(file_out, "M")
        } else {
            if (plus_gender == 0) {
                writeStringToFile(file_out, "F")
            } else {
                writeStringToFile(file_out, "X")
            }
        }
        writeStringToFile(file_out, " ")
        p += 2;

        if (plus_birthdate_year == 0) {
            writeStringToFile(file_out, "X ")
            p += 2;
        } else {
            writeStringToFile(file_out, String(format: "%02d-", plus_birthdate_day))
            switch (plus_birthdate_month) {
            case 1:
                writeStringToFile(file_out, "JAN")
                break;
            case 2:
                writeStringToFile(file_out, "FEB")
                break;
            case 3:
                writeStringToFile(file_out, "MAR")
                break;
            case 4:
                writeStringToFile(file_out, "APR")
                break;
            case 5:
                writeStringToFile(file_out, "MAY")
                break;
            case 6:
                writeStringToFile(file_out, "JUN")
                break;
            case 7:
                writeStringToFile(file_out, "JUL")
                break;
            case 8:
                writeStringToFile(file_out, "AUG")
                break;
            case 9:
                writeStringToFile(file_out, "SEP")
                break;
            case 10:
                writeStringToFile(file_out, "OCT")
                break;
            case 11:
                writeStringToFile(file_out, "NOV")
                break;
            case 12:
                writeStringToFile(file_out, "DEC")
                break;
            default:
                writeStringToFile(file_out, "ERR")
                break;
            }
            writeStringToFile(file_out, String(format: "-%04d", plus_birthdate_year))
            p += 12;
        }

        if (plus_patient_name != nil) {
            len = plus_patient_name!.count
        } else {
            len = 0;
        }
        if ((len != 0) && (rest != 0)) {
            if (len > rest) {
                len = rest;
                rest = 0;
            } else {
                rest -= len;
            }
            bufcpy(dest: &str, src: Array(plus_patient_name.utf8));
            latin1_to_ascii(str: &str, len: len);
            for i in 0 ..< len {
                if (str[i] == UInt8FromChar(" ")) {
                    str[i] = UInt8FromChar(" ")
                }
            }
            file_out.write(Data(bytes: str, count: len))
            p += len;
        } else {
            writeStringToFile(file_out, "X")
            p += 1
        }

        if (rest != 0) {
            writeStringToFile(file_out, " ")

            p += 1

            rest -= 1
        }

        if (plus_patient_additional != nil) {
            len = plus_patient_additional!.count
        } else {
            len = 0;
        }
        if ((len != 0) && (rest != 0)) {
            if (len > rest) {
                len = rest;
            }
            bufcpy(dest: &str, src: Array(plus_patient_additional!.utf8));
            latin1_to_ascii(str: &str, len: len);
            file_out.write(Data(bytes: str, count: len))
            p += len;
        }

        repeat
        {
            writeStringToFile(file_out, " ")
            p += 1
        } while (p<80)

        if (startdate_year == 0) {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())

            startdate_year = components.year
            startdate_month = components.month
            startdate_day = components.day
            starttime_hour = components.hour
            starttime_minute = components.minute
            starttime_second = components.second
        }

        writeStringToFile(file_out, String(format: "Startdate %02d-", startdate_day))
        switch (startdate_month) {
        case 1:
            writeStringToFile(file_out, "JAN")
            break;
        case 2:
            writeStringToFile(file_out, "FEB")
            break;
        case 3:
            writeStringToFile(file_out, "MAR")
            break;
        case 4:
            writeStringToFile(file_out, "APR")
            break;
        case 5:
            writeStringToFile(file_out, "MAY")
            break;
        case 6:
            writeStringToFile(file_out, "JUN")
            break;
        case 7:
            writeStringToFile(file_out, "JUL")
            break;
        case 8:
            writeStringToFile(file_out, "AUG")
            break;
        case 9:
            writeStringToFile(file_out, "SEP")
            break;
        case 10:
            writeStringToFile(file_out, "OCT")
            break;
        case 11:
            writeStringToFile(file_out, "NOV")
            break;
        case 12:
            writeStringToFile(file_out, "DEC")
            break;
        default:
            writeStringToFile(file_out, "ERR")
            break;
        }
        writeStringToFile(file_out, String(format: "-%04d ", startdate_year))
        p = 22;

        rest = 42;

        if (plus_admincode != nil) {
            len = plus_admincode!.count
        } else {
            len = 0;
        }
        if ((len != 0) && (rest != 0)) {
            if (len > rest) {
                len = rest;
                rest = 0;
            } else {
                rest -= len;
            }
            bufcpy(dest: &str, src: Array(plus_admincode.utf8))
            latin1_to_ascii(str: &str, len: len);
            for i in 0 ..< len {
                if (str[i] == UInt8FromChar(" ")) {
                    str[i] = UInt8FromChar("_")
                }
            }
            file_out.write(Data(bytes: str, count: len))
            p += len;
        } else {
            writeStringToFile(file_out, "X")
            p += 1
        }

        if (rest != 0) {
            writeStringToFile(file_out, " ")
            p += 1
            rest -= 1
        }

        if (plus_technician != nil) {
            len = plus_technician!.count
        } else {
            len = 0;
        }
        if ((len != 0) && (rest != 0)) {
            if (len > rest) {
                len = rest;
                rest = 0;
            } else {
                rest -= len;
            }
            bufcpy(dest: &str, src: Array(plus_technician!.utf8))
            latin1_to_ascii(str: &str, len: len);
            for i in 0 ..< len {
                if (str[i] == UInt8FromChar(" ")) {
                    str[i] = UInt8FromChar("_")
                }
            }
            file_out.write(Data(bytes: str, count: len))
            p += len;
        } else {
            writeStringToFile(file_out, "X")
            p += 1
        }

        if (rest != 0) {
            writeStringToFile(file_out, " ")
            p += 1
            rest -= 1
        }

        if (plus_equipment != nil) {
            len = plus_equipment!.count
        } else {
            len = 0;
        }
        if ((len != 0) && (rest != 0)) {
            if (len > rest) {
                len = rest;
                rest = 0;
            } else {
                rest -= len;
            }
            bufcpy(dest: &str, src: Array(plus_equipment!.utf8))
            latin1_to_ascii(str: &str, len: len);
            for i in 0 ..< len {
                if (str[i] == UInt8FromChar(" ")) {
                    str[i] = UInt8FromChar("_")
                }
            }
            file_out.write(Data(bytes: str, count: len))
            p += len;
        } else {
            writeStringToFile(file_out, "X")
            p += 1
        }

        if (rest != 0) {
            writeStringToFile(file_out, " ")
            p += 1
            rest -= 1
        }

        if (plus_recording_additional != nil) {
            len = plus_recording_additional!.count
        } else {
            len = 0;
        }
        if ((len != 0) && (rest != 0)) {
            if (len > rest) {
                len = rest;
                rest = 0;
            } else {
                rest -= len;
            }
            bufcpy(dest: &str, src: Array(plus_equipment!.utf8))
            latin1_to_ascii(str: &str, len: len);
            for i in 0 ..< len {
                if (str[i] == UInt8FromChar(" ")) {
                    str[i] = UInt8FromChar("_")
                }
            }
            file_out.write(Data(bytes: str, count: len))
            p += len;
        }

        repeat
        {
            writeStringToFile(file_out, " ")

            p += 1
        } while(p < 80)

        writeStringToFile(file_out, String(format: "%02d.%02d.%02d", startdate_day, startdate_month, (startdate_year % 100)))
        writeStringToFile(file_out, String(format: "%02d.%02d.%02d", starttime_hour, starttime_minute, starttime_second))

        p = fprint_int_number_nonlocalized(file: file_out, q: (edfsignals + nr_annot_chns + 1) * 256, minimum: 0, sign: 0)

        repeat
        {
            writeStringToFile(file_out, " ")
            p += 1
        } while(p < 8)

        if (edf != 0) {
            writeStringToFile(file_out, "EDF+C")
        } else {
            writeStringToFile(file_out, "BDF+C")
        }
        for i in 0 ..< 39 {
            writeStringToFile(file_out, " ")
        }
        writeStringToFile(file_out, "-1      ")
        if (long_data_record_duration == EDFWriter.EDFLIB_TIME_DIMENSION) {
            writeStringToFile(file_out, "1       ")
        } else {
            p = sprint_number_nonlocalized(dest: &str, val: Double((long_data_record_duration) / EDFWriter.EDFLIB_TIME_DIMENSION));
            repeat
            {
                str[p] = UInt8FromChar(" ")
                p += 1
            } while (p < 8)

            file_out.write(Data(bytes: str, count: 8))
        }
        p = fprint_int_number_nonlocalized(file: file_out, q: edfsignals + nr_annot_chns, minimum: 0, sign: 0);
        repeat
        {
            writeStringToFile(file_out, " ")
            p += 1
        } while (p < 4)

        for i in 0 ..< edfsignals {
            if (param_label[i].count > 0) {
                len = param_label[i].count
            } else {
                len = 0;
            }
            if (len != 0) {
                if (len > 16) {
                    len = 16;
                }
                bufcpy(dest: &str, src: Array(param_label[i].utf8));
                latin1_to_ascii(str: &str, len: len);
                file_out.write(Data(bytes: str, count: len))
            }
            for j in len ..< 16 {
                writeStringToFile(file_out, " ")
            }
        }
        for j in 0 ..< nr_annot_chns {
            if (edf != 0) {
                writeStringToFile(file_out, "EDF Annotations ")
            } else {
                writeStringToFile(file_out, "BDF Annotations ")
            }
        }
        for i in 0 ..< edfsignals {
            if (param_transducer[i].count > 0) {
                len = param_transducer[i].count
            } else {
                len = 0;
            }
            if (len != 0) {
                if (len > 80) {
                    len = 80;
                }
                bufcpy(dest: &str, src: Array(param_transducer[i].utf8));
                latin1_to_ascii(str: &str, len: len);
                file_out.write(Data(bytes: str, count: len))
            }
            for j in len ..< 80 {
                writeStringToFile(file_out, " ")
            }
        }
        for j in 0 ..< nr_annot_chns {
            for i in 0 ..< 80 {
                writeStringToFile(file_out, " ")
            }
        }
        for i in 0 ..< edfsignals {
            if (param_physdimension[i].count > 0) {
                len = param_physdimension[i].count
            } else {
                len = 0;
            }
            if (len != 0) {
                if (len > 8) {
                    len = 8;
                }
                bufcpy(dest: &str, src: Array(param_physdimension[i].utf8));
                latin1_to_ascii(str: &str, len: len);
                file_out.write(Data(bytes: str, count: len))
            }
            for j in len ..< 8 {
                writeStringToFile(file_out, " ")
            }
        }
        for j in 0 ..< nr_annot_chns {
            for i in 0 ..< 8 {
                writeStringToFile(file_out, " ")
            }
        }
        for i in 0 ..< edfsignals {
            p = sprint_number_nonlocalized(dest: &str, val: param_phys_min[i]);
            repeat
            {
                str[p] = UInt8FromChar(" ")
                p += 1
            } while (p < 8)
            file_out.write(Data(bytes: str, count: 8))
        }
        for j in 0 ..< nr_annot_chns {
            writeStringToFile(file_out, "-1      ")
        }

        for i in 0 ..< edfsignals {
            p = sprint_number_nonlocalized(dest: &str, val: param_phys_max[i]);

            repeat
            {
                str[p] = UInt8FromChar(" ")
                p += 1
            } while (p < 8)

            file_out.write(Data(bytes: str, count: 8))
        }
        for j in 0 ..< nr_annot_chns {
            writeStringToFile(file_out, "1       ")
        }
        for i in 0 ..< edfsignals {
            p = fprint_int_number_nonlocalized(file: file_out, q: param_dig_min[i], minimum: 0, sign: 0);

            repeat
            {
                writeStringToFile(file_out, " ")
                p += 1
            } while (p < 8)

        }

        for j in 0 ..< nr_annot_chns {
            if (edf != 0) {
                writeStringToFile(file_out, "-32768  ")
            } else {
                writeStringToFile(file_out, "-8388608")
            }
        }

        for i in 0 ..< edfsignals {
            p = fprint_int_number_nonlocalized(file: file_out, q: param_dig_max[i], minimum: 0, sign: 0);

            repeat
            {
                writeStringToFile(file_out, " ")
                p += 1
            } while (p < 8)

        }
        for j in 0 ..< nr_annot_chns {
            if (edf != 0) {
                writeStringToFile(file_out, "32767   ")
            } else {
                writeStringToFile(file_out, "8388607 ")
            }
        }

        for i in 0 ..< edfsignals {
            if (param_prefilter[i].count > 0) {
                len = param_prefilter[i].count
            } else {
                len = 0;
            }
            if (len != 0) {
                if (len > 80) {
                    len = 80;
                }
                bufcpy(dest: &str, src: Array(param_prefilter[i].utf8));
                latin1_to_ascii(str: &str, len: len);
                file_out.write(Data(bytes: str, count: len))
            }
            for j in len ..< 80 {
                writeStringToFile(file_out, " ")
            }
        }

        for j in 0 ..< nr_annot_chns {
            for i in 0 ..< 80 {
                writeStringToFile(file_out, " ")
            }
        }

        for i in 0 ..< edfsignals {
            p = fprint_int_number_nonlocalized(file: file_out, q: param_smp_per_record[i], minimum: 0, sign: 0);

            repeat
            {
                writeStringToFile(file_out, " ")
                p += 1
            } while (p < 8)

        }

        for j in 0 ..< nr_annot_chns {
            if (edf != 0) {
                p = fprint_int_number_nonlocalized(file: file_out, q: EDFLIB_ANNOTATION_BYTES / 2, minimum: 0, sign: 0);
            } else {
                p = fprint_int_number_nonlocalized(file: file_out, q: EDFLIB_ANNOTATION_BYTES / 3, minimum: 0, sign: 0);
            }

            repeat
            {
                writeStringToFile(file_out, " ")
                p += 1
            } while (p < 8)
        }

        for i in 0 ..< ((edfsignals + nr_annot_chns) * 32)
        {
            writeStringToFile(file_out, " ")
        }

        return 0;
    }



    /**
     * Writes n "raw" digital samples from buf belonging to one signal. <br>
     * where n is the samplefrequency of that signal.<br>
     * The 16 (or 24 in case of BDF) least significant bits of the sample will be
     * written to the<br>
     * file without any conversion.<br>
     * The number of samples written is equal to the samplefrequency of the
     * signal<br>
     * (actually, it's the value that is set with setSampleFrequency()).<br>
     * Size of buf should be equal to or bigger than the samplefrequency<br>
     * Call this function for every signal in the file. The order is important!<br>
     * When there are 4 signals in the file, the order of calling this function<br>
     * must be: signal 0, signal 1, signal 2, signal 3, signal 0, signal 1, signal
     * 2, etc.<br>
     * The end of a recording must always be at the end of a complete cycle.<br>
     *
     * @param buf
     *
     * @throws IOException
     *
     * @return 0 on success, otherwise non-zero
     */
    public func writeDigitalSamples(buf : [Int]) -> Int {
        var i = 0
        var error = 0
        var sf = 0
        var digmax = 0
        var digmin = 0
        var edfsignal = 0
        var value = 0

        if (status_ok == 0)
        {
            return -1;
        }

        edfsignal = signal_write_sequence_pos;

        if (datarecords == 0) {
            if (edfsignal == 0) {
                error = write_edf_header();

                if (error != 0) {
                    return error;
                }
            }
        }

        sf = param_smp_per_record[edfsignal];

        digmax = param_dig_max[edfsignal];

        digmin = param_dig_min[edfsignal];

        if (sf > buf.count)
        {
            return -1;
        }

        if (edf != 0) {
            if (wrbufsz < (sf * 2)) {
                wrbuf = [Int8](repeating: 0, count: sf * 2)

                wrbufsz = sf * 2;
            }

            for i in 0 ..< sf {
                value = buf[i];

                if (value > digmax) {
                    value = digmax;
                }

                if (value < digmin) {
                    value = digmin;
                }

                wrbuf[i * 2] = Int8(bitPattern: UInt8(value & 0xFF))

                wrbuf[i * 2 + 1] = Int8(bitPattern: UInt8((value >> 8) & 0xFF))
            }

            file_out.write(Data(bytes: wrbuf, count: sf * 2))
        } else {
            if (wrbufsz < (sf * 3)) {
                wrbuf = [Int8](repeating: 0, count: sf * 3)

                wrbufsz = sf * 3;
            }

            for i in 0 ..< sf {
                value = buf[i];

                if (value > digmax) {
                    value = digmax;
                }

                if (value < digmin) {
                    value = digmin;
                }

                wrbuf[i * 3] = Int8(bitPattern: UInt8(value & 0xFF))

                wrbuf[i * 3 + 1] = Int8(bitPattern: UInt8((value >> 8) & 0xFF))

                wrbuf[i * 3 + 2] = Int8(bitPattern: UInt8((value >> 16) & 0xFF))
            }

            file_out.write(Data(bytes: wrbuf, count: sf * 3))
        }

        signal_write_sequence_pos += 1

        if (signal_write_sequence_pos == edfsignals) {
            signal_write_sequence_pos = 0;

            if (write_tal(file: file_out) != 0) {
                return -1;
            }

            datarecords += 1
        }

        return 0;
    }


    /**
     * Writes "raw" digital samples of all signals from buf into the file. <br>
     * buf must be filled with samples from all signals, starting with n samples of
     * signal 0, n samples of signal 1, n samples of signal 2, etc.<br>
     * where n is the samplefrequency of that signal.<br>
     * The 16 (or 24 in case of BDF) least significant bits of the sample will be
     * written to the file without any conversion.<br>
     * The number of samples written is equal to the sum of the samplefrequencies of
     * all signals.<br>
     * Size of buf should be equal to or bigger than the sum of the
     * samplefrequencies of all signals.<br>
     *
     * @param buf
     *
     * @throws IOException
     *
     * @return 0 on success, otherwise non-zero
     */
    public func blockWriteDigitalSamples(buf : [Int]) -> Int {
        var i = 0
        var j = 0
        var error = 0
        var sf = 0
        var digmax = 0
        var digmin = 0
        var edfsignal = 0
        var value = 0
        var buf_offset = 0

        if (status_ok == 0)
        {
            return -1;
        }

        if (signal_write_sequence_pos != 0)
        {
            return -1;
        }

        if (datarecords == 0) {
            error = write_edf_header();

            if (error != 0) {
                return error;
            }
        }

        for edfsignal in 0 ..< edfsignals {
            sf = param_smp_per_record[edfsignal];

            digmax = param_dig_max[edfsignal];

            digmin = param_dig_min[edfsignal];

            if (sf > buf.count)
            {
                return -1;
            }

            if (edf != 0) {
                if (wrbufsz < (sf * 2)) {
                    wrbuf = [Int8](repeating: 0, count: sf * 2)

                    wrbufsz = sf * 2;
                }

                for i in 0 ..< sf {

                    value = buf[i + buf_offset];

                    if (value > digmax) {
                        value = digmax;
                    }

                    if (value < digmin) {
                        value = digmin;
                    }

                    wrbuf[i * 2] = Int8(bitPattern: UInt8(value & 0xFF))

                    wrbuf[i * 2 + 1] = Int8(bitPattern: UInt8((value >> 8) & 0xFF))
                }

                file_out.write(Data(bytes: wrbuf, count: sf * 2))
            } else {
                if (wrbufsz < (sf * 3)) {
                    wrbuf = [Int8](repeating: 0, count: sf * 3)

                    wrbufsz = sf * 3;
                }

                for i in 0 ..< sf {
                    value = buf[i + buf_offset];

                    if (value > digmax) {
                        value = digmax;
                    }

                    if (value < digmin) {
                        value = digmin;
                    }

                    wrbuf[i * 3] = Int8(bitPattern: UInt8(value & 0xFF))

                    wrbuf[i * 3 + 1] = Int8(bitPattern: UInt8((value >> 8) & 0xFF))

                    wrbuf[i * 3 + 2] = Int8(bitPattern: UInt8((value >> 16) & 0xFF))
                }

                file_out.write(Data(bytes: wrbuf, count: sf * 3))
            }

            buf_offset += sf;
        }

        if (write_tal(file: file_out) != 0) {
            return -1;
        }

        datarecords += 1

        return 0;
    }

    /**
     * For use with BDF only.&nbsp;Writes "raw" digital samples of all signals from
     * buf into the file. <br>
     * buf must be filled with samples from all signals, starting with n samples of
     * signal 0, n samples of signal 1, n samples of signal 2, etc.<br>
     * where n is the samplefrequency of that signal.<br>
     * A sample consists of three consecutive bytes (24 bits, little endian,
     * seconds' complement) and will be written to the file without any
     * conversion.<br>
     * The number of samples written is equal to the sum of the samplefrequencies of
     * all signals.<br>
     * Size of buf should be equal to or bigger than the sum of the
     * samplefrequencies of all signals * 3.<br>
     *
     * @param buf
     *
     * @throws IOException
     *
     * @return 0 on success, otherwise non-zero
     */
    public func blockWriteDigital3ByteSamples(buf : [UInt8]) -> Int {
        var j = 0
        var error = 0
        var total_samples = 0;

        if (status_ok == 0)
        {
            return -1;
        }

        if (signal_write_sequence_pos != 0)
        {
            return -1;
        }

        if (bdf != 1) {
            return -1;
        }

        for j in 0 ..< edfsignals {
            total_samples += param_smp_per_record[j];
        }

        if (datarecords == 0) {
            error = write_edf_header();

            if (error != 0) {
                return error;
            }
        }

        file_out.write(Data(bytes: buf, count: total_samples * 3))

        if (write_tal(file: file_out) != 0) {
            return -1;
        }

        datarecords += 1

        return 0;
    }


    /**
     * Writes "raw" digital samples of all signals from buf into the file. <br>
     * buf must be filled with samples from all signals, starting with n samples of
     * signal 0, n samples of signal 1, n samples of signal 2, etc.<br>
     * where n is the samplefrequency of that signal.<br>
     * The 16 (or 24 in case of BDF) least significant bits of the sample will be
     * written to the file without any conversion.<br>
     * The number of samples written is equal to the sum of the samplefrequencies of
     * all signals.<br>
     * Size of buf should be equal to or bigger than the sum of the
     * samplefrequencies of all signals.<br>
     *
     * @param buf
     *
     * @throws IOException
     *
     * @return 0 on success, otherwise non-zero
     */
    public func blockWriteDigitalShortSamples(buf : [Int]) -> Int {
        var i = 0
        var j = 0
        var error = 0
        var sf = 0
        var digmax = 0
        var digmin = 0
        var edfsignal = 0
        var value = 0
        var buf_offset = 0


        if (status_ok == 0)
        {
            return -1;
        }

        if (signal_write_sequence_pos != 0)
        {
            return -1;
        }

        if (datarecords == 0) {
            error = write_edf_header();

            if (error != 0) {
                return error;
            }
        }

        for edfsignal in 0 ..< edfsignals {
            sf = param_smp_per_record[edfsignal];

            digmax = param_dig_max[edfsignal];

            digmin = param_dig_min[edfsignal];

            if (sf > buf.count)
            {
                return -1;
            }

            if (edf != 0) {
                if (wrbufsz < (sf * 2)) {
                    wrbuf = [Int8](repeating: 0, count: sf * 2)

                    wrbufsz = sf * 2;
                }

                for i in 0 ..< sf {
                    value = buf[i + buf_offset];

                    if (value > digmax) {
                        value = digmax;
                    }

                    if (value < digmin) {
                        value = digmin;
                    }

                    wrbuf[i * 2] =  Int8(bitPattern: UInt8(value & 0xFF))

                    wrbuf[i * 2 + 1] = Int8(bitPattern: UInt8((value >> 8) & 0xFF))
                }

                file_out.write(Data(bytes: wrbuf, count: sf * 2))
            } else {
                if (wrbufsz < (sf * 3)) {
                    wrbuf = [Int8](repeating: 0, count: sf * 3)

                    wrbufsz = sf * 3;
                }

                for i in 0 ..< sf {
                    value = buf[i + buf_offset];

                    if (value > digmax) {
                        value = digmax;
                    }

                    if (value < digmin) {
                        value = digmin;
                    }

                    wrbuf[i * 3] = Int8(bitPattern: UInt8(value & 0xFF))

                    wrbuf[i * 3 + 1] = Int8(bitPattern: UInt8((value >> 8) & 0xFF))

                    wrbuf[i * 3 + 2] = Int8(bitPattern: UInt8((value >> 16) & 0xFF))
                }

                file_out.write(Data(bytes: wrbuf, count: sf * 3))
            }

            buf_offset += sf;
        }

        if (write_tal(file: file_out) != 0) {
            return -1;
        }

        datarecords += 1

        return 0;
    }

    /**
     * Writes n "raw" digital samples from buf belonging to one signal. <br>
     * where n is the samplefrequency of that signal.<br>
     * The 16 (or 24 in case of BDF) least significant bits of the sample will be
     * written to the<br>
     * file without any conversion.<br>
     * The number of samples written is equal to the samplefrequency of the
     * signal<br>
     * (actually, it's the value that is set with setSampleFrequency()).<br>
     * Size of buf should be equal to or bigger than the samplefrequency<br>
     * Call this function for every signal in the file. The order is important!<br>
     * When there are 4 signals in the file, the order of calling this function<br>
     * must be: signal 0, signal 1, signal 2, signal 3, signal 0, signal 1, signal
     * 2, etc.<br>
     * The end of a recording must always be at the end of a complete cycle.<br>
     *
     * @param buf
     *
     * @throws IOException
     *
     * @return 0 on success, otherwise non-zero
     */
    public func writeDigitalShortSamples(buf : [Int]) -> Int {
        var i = 0
        var error = 0
        var sf = 0
        var digmax = 0
        var digmin = 0
        var edfsignal = 0
        var value = 0


        if (status_ok == 0)
        {
            return -1;
        }

        edfsignal = signal_write_sequence_pos;

        if (datarecords == 0) {
            if (edfsignal == 0) {
                error = write_edf_header();

                if (error != 0) {
                    return error;
                }
            }
        }

        sf = param_smp_per_record[edfsignal];

        digmax = param_dig_max[edfsignal];

        digmin = param_dig_min[edfsignal];

        if (sf > buf.count)
        {
            return -1;
        }

        if (edf != 0) {
            if (wrbufsz < (sf * 2)) {
                wrbuf = [Int8](repeating: 0, count: sf * 2)

                wrbufsz = sf * 2;
            }

            for i in 0 ..< sf {
                value = buf[i];

                if (value > digmax) {
                    value = digmax;
                }

                if (value < digmin) {
                    value = digmin;
                }

                wrbuf[i * 2] = Int8(bitPattern: UInt8(value & 0xFF))

                wrbuf[i * 2 + 1] = Int8(bitPattern: UInt8((value >> 8) & 0xFF))
            }

            file_out.write(Data(bytes: wrbuf, count: sf * 2))
        } else {
            if (wrbufsz < (sf * 3)) {
                wrbuf = [Int8](repeating: 0, count: sf * 3)

                wrbufsz = sf * 3;
            }

            for i in 0 ..< sf {
                value = buf[i];

                if (value > digmax) {
                    value = digmax;
                }

                if (value < digmin) {
                    value = digmin;
                }

                wrbuf[i * 3] = Int8(bitPattern: UInt8(value & 0xFF))

                wrbuf[i * 3 + 1] = Int8(bitPattern: UInt8((value >> 8) & 0xFF))

                wrbuf[i * 3 + 2] =  Int8(bitPattern: UInt8((value >> 16) & 0xFF))
            }

            file_out.write(Data(bytes: wrbuf, count: sf * 3))
        }

        signal_write_sequence_pos += 1

        if (signal_write_sequence_pos == edfsignals) {
            signal_write_sequence_pos = 0;

            if (write_tal(file: file_out) != 0) {
                return -1;
            }

            datarecords += 1
        }

        return 0;
    }



    /**
     * Writes n "physical" samples (uV, mmHg, Ohm, etc.) from buf belonging to one
     * signal. <br>
     * where n is the samplefrequency of that signal.<br>
     * The physical samples will be converted to digital samples using the<br>
     * values of physical maximum, physical minimum, digital maximum and digital
     * minimum.<br>
     * The number of samples written is equal to the samplefrequency of the
     * signal<br>
     * (actually, it's the value that is set with setSampleFrequency()).<br>
     * Size of buf should be equal to or bigger than the samplefrequency<br>
     * Call this function for every signal in the file. The order is important!<br>
     * When there are 4 signals in the file, the order of calling this function<br>
     * must be: signal 0, signal 1, signal 2, signal 3, signal 0, signal 1, signal
     * 2, etc.<br>
     * The end of a recording must always be at the end of a complete cycle.<br>
     *
     * @param buf
     *
     * @throws IOException
     *
     * @return 0 on success, otherwise non-zero
     */
    public func writePhysicalSamples(buf : [Double]) -> Int {
        var i = 0
        var error = 0
        var sf = 0
        var digmax = 0
        var digmin = 0
        var edfsignal = 0
        var value = 0

        if (status_ok == 0)
        {
            return -1;
        }

        edfsignal = signal_write_sequence_pos;

        if (datarecords == 0) {
            if (edfsignal == 0) {
                error = write_edf_header();

                if (error != 0) {
                    return error;
                }
            }
        }

        sf = param_smp_per_record[edfsignal];

        digmax = param_dig_max[edfsignal];

        digmin = param_dig_min[edfsignal];

        if (sf > buf.count)
        {
            return -1;
        }

        if (edf != 0) {
            if (wrbufsz < (sf * 2)) {
                wrbuf = [Int8](repeating: 0, count: sf * 2)

                wrbufsz = sf * 2;
            }

            for i in 0 ..< sf {
                value = Int(((buf[i] / param_bitvalue[edfsignal]) - param_offset[edfsignal]));

                if (value > digmax) {
                    value = digmax;
                }

                if (value < digmin) {
                    value = digmin;
                }

                wrbuf[i * 2] = Int8(bitPattern: UInt8(value & 0xFF))

                wrbuf[i * 2 + 1] = Int8(bitPattern: UInt8((value >> 8) & 0xFF))
            }

            file_out.write(Data(bytes: wrbuf, count: sf * 2))
        } else {
            if (wrbufsz < (sf * 3)) {
                wrbuf = [Int8](repeating: 0, count: sf * 3)

                wrbufsz = sf * 3;
            }

            for i in 0 ..< sf {
                value = Int(((buf[i] / param_bitvalue[edfsignal]) - param_offset[edfsignal]));

                if (value > digmax) {
                    value = digmax;
                }

                if (value < digmin) {
                    value = digmin;
                }

                wrbuf[i * 3] =  Int8(bitPattern: UInt8(value & 0xFF))

                wrbuf[i * 3 + 1] = Int8(bitPattern: UInt8((value >> 8) & 0xFF))

                wrbuf[i * 3 + 2] =  Int8(bitPattern: UInt8((value >> 16) & 0xFF))
            }

            file_out.write(Data(bytes: wrbuf, count: sf * 3))
        }

        signal_write_sequence_pos += 1

        if (signal_write_sequence_pos == edfsignals) {
            signal_write_sequence_pos = 0;

            if (write_tal(file: file_out) != 0) {
                return -1;
            }

            datarecords += 1
        }

        return 0;
    }

    /**
     * Writes "physical" samples (uV, mmHg, Ohm, etc.) of all signals from buf into
     * the file. <br>
     * buf must be filled with samples from all signals, starting with n samples of
     * signal 0, n samples of signal 1, n samples of signal 2, etc.<br>
     * where n is the samplefrequency of that signal.<br>
     * The physical samples will be converted to digital samples using the<br>
     * values of physical maximum, physical minimum, digital maximum and digital
     * minimum.<br>
     * The number of samples written is equal to the sum of the samplefrequencies of
     * all signals.<br>
     * Size of buf should be equal to or bigger than the sum of the
     * samplefrequencies of all signals.<br>
     *
     * @param buf
     *
     * @throws IOException
     *
     * @return 0 on success, otherwise non-zero
     */
    public func blockWritePhysicalSamples(buf : [Double]) -> Int {
        var i = 0
        var j = 0
        var error = 0
        var sf = 0
        var digmax = 0
        var digmin = 0
        var edfsignal = 0
        var value = 0
        var buf_offset = 0

        if (status_ok == 0)
        {
            return -1;
        }

        if (signal_write_sequence_pos != 0)
        {
            return -1;
        }

        if (datarecords == 0) {
            error = write_edf_header();

            if (error != 0) {
                return error;
            }
        }

        for edfsignal in 0 ..< edfsignals {
            sf = param_smp_per_record[edfsignal];

            digmax = param_dig_max[edfsignal];

            digmin = param_dig_min[edfsignal];

            if (sf > buf.count)
            {
                return -1;
            }

            if (edf != 0) {
                if (wrbufsz < (sf * 2)) {
                    wrbuf = [Int8](repeating: 0, count: sf * 2)

                    wrbufsz = sf * 2;
                }

                for i in 0 ..< sf {
                    value = Int(((buf[i + buf_offset] / param_bitvalue[edfsignal]) - param_offset[edfsignal]));

                    if (value > digmax) {
                        value = digmax;
                    }

                    if (value < digmin) {
                        value = digmin;
                    }

                    wrbuf[i * 2] = Int8(bitPattern: UInt8(value & 0xFF))

                    wrbuf[i * 2 + 1] = Int8(bitPattern: UInt8((value >> 8) & 0xFF))
                }

                file_out.write(Data(bytes: wrbuf, count: sf * 2))
            } else {
                if (wrbufsz < (sf * 3)) {
                    wrbuf = [Int8](repeating: 0, count: sf * 3)

                    wrbufsz = sf * 3;
                }

                for i in 0 ..< sf {
                    value = Int(((buf[i + buf_offset] / param_bitvalue[edfsignal]) - param_offset[edfsignal]));

                    if (value > digmax) {
                        value = digmax;
                    }

                    if (value < digmin) {
                        value = digmin;
                    }

                    wrbuf[i * 3] =  Int8(bitPattern: UInt8(value & 0xFF))

                    wrbuf[i * 3 + 1] = Int8(bitPattern: UInt8((value >> 8) & 0xFF))

                    wrbuf[i * 3 + 2] = Int8(bitPattern: UInt8((value >> 16) & 0xFF))
                }

                file_out.write(Data(bytes: wrbuf, count: sf * 3))
            }

            buf_offset += sf;
        }

        if (write_tal(file: file_out) != 0) {
            return -1;
        }

        datarecords += 1

        return 0;
    }
}
