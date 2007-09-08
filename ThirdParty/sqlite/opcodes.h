/* Automatically generated.  Do not edit */
/* See the mkopcodeh.awk script for details */
#define OP_ReadCookie                           1
#define OP_AutoCommit                           2
#define OP_Found                                3
#define OP_NullRow                              4
#define OP_Lt                                  71   /* same as TK_LT       */
#define OP_MoveLe                               5
#define OP_Variable                             6
#define OP_Pull                                 7
#define OP_RealAffinity                         8
#define OP_Sort                                 9
#define OP_IfNot                               10
#define OP_Gosub                               11
#define OP_Add                                 78   /* same as TK_PLUS     */
#define OP_NotFound                            12
#define OP_IsNull                              65   /* same as TK_ISNULL   */
#define OP_MoveLt                              13
#define OP_Rowid                               14
#define OP_CreateIndex                         15
#define OP_Push                                17
#define OP_Explain                             18
#define OP_Statement                           19
#define OP_Callback                            20
#define OP_MemLoad                             21
#define OP_DropIndex                           22
#define OP_Null                                23
#define OP_ToInt                              141   /* same as TK_TO_INT   */
#define OP_Int64                               24
#define OP_LoadAnalysis                        25
#define OP_IdxInsert                           26
#define OP_VUpdate                             27
#define OP_Next                                28
#define OP_SetNumColumns                       29
#define OP_ToNumeric                          140   /* same as TK_TO_NUMERIC*/
#define OP_Ge                                  72   /* same as TK_GE       */
#define OP_BitNot                              87   /* same as TK_BITNOT   */
#define OP_MemInt                              30
#define OP_Dup                                 31
#define OP_Rewind                              32
#define OP_Multiply                            80   /* same as TK_STAR     */
#define OP_ToReal                             142   /* same as TK_TO_REAL  */
#define OP_Gt                                  69   /* same as TK_GT       */
#define OP_Last                                33
#define OP_MustBeInt                           34
#define OP_Ne                                  67   /* same as TK_NE       */
#define OP_MoveGe                              35
#define OP_IncrVacuum                          36
#define OP_String                              37
#define OP_VFilter                             38
#define OP_ForceInt                            39
#define OP_Close                               40
#define OP_AggFinal                            41
#define OP_AbsValue                            42
#define OP_RowData                             43
#define OP_IdxRowid                            44
#define OP_BitOr                               75   /* same as TK_BITOR    */
#define OP_NotNull                             66   /* same as TK_NOTNULL  */
#define OP_MoveGt                              45
#define OP_Not                                 16   /* same as TK_NOT      */
#define OP_OpenPseudo                          46
#define OP_Halt                                47
#define OP_MemMove                             48
#define OP_NewRowid                            49
#define OP_Real                               125   /* same as TK_FLOAT    */
#define OP_IdxLT                               50
#define OP_Distinct                            51
#define OP_MemMax                              52
#define OP_Function                            53
#define OP_IntegrityCk                         54
#define OP_Remainder                           82   /* same as TK_REM      */
#define OP_HexBlob                            126   /* same as TK_BLOB     */
#define OP_ShiftLeft                           76   /* same as TK_LSHIFT   */
#define OP_FifoWrite                           55
#define OP_BitAnd                              74   /* same as TK_BITAND   */
#define OP_Or                                  60   /* same as TK_OR       */
#define OP_NotExists                           56
#define OP_VDestroy                            57
#define OP_MemStore                            58
#define OP_IdxDelete                           59
#define OP_Vacuum                              62
#define OP_If                                  63
#define OP_Destroy                             64
#define OP_AggStep                             73
#define OP_Clear                               84
#define OP_Insert                              86
#define OP_VBegin                              89
#define OP_IdxGE                               90
#define OP_OpenEphemeral                       91
#define OP_Divide                              81   /* same as TK_SLASH    */
#define OP_String8                             88   /* same as TK_STRING   */
#define OP_IfMemZero                           92
#define OP_Concat                              83   /* same as TK_CONCAT   */
#define OP_VRowid                              93
#define OP_MakeRecord                          94
#define OP_SetCookie                           95
#define OP_Prev                                96
#define OP_ContextPush                         97
#define OP_DropTrigger                         98
#define OP_IdxGT                               99
#define OP_MemNull                            100
#define OP_IfMemNeg                           101
#define OP_And                                 61   /* same as TK_AND      */
#define OP_VColumn                            102
#define OP_Return                             103
#define OP_OpenWrite                          104
#define OP_Integer                            105
#define OP_Transaction                        106
#define OP_CollSeq                            107
#define OP_VRename                            108
#define OP_ToBlob                             139   /* same as TK_TO_BLOB  */
#define OP_Sequence                           109
#define OP_ContextPop                         110
#define OP_ShiftRight                          77   /* same as TK_RSHIFT   */
#define OP_VCreate                            111
#define OP_CreateTable                        112
#define OP_AddImm                             113
#define OP_ToText                             138   /* same as TK_TO_TEXT  */
#define OP_DropTable                          114
#define OP_IsUnique                           115
#define OP_VOpen                              116
#define OP_Noop                               117
#define OP_RowKey                             118
#define OP_Expire                             119
#define OP_FifoRead                           120
#define OP_Delete                             121
#define OP_IfMemPos                           122
#define OP_Subtract                            79   /* same as TK_MINUS    */
#define OP_MemIncr                            123
#define OP_Blob                               124
#define OP_MakeIdxRec                         127
#define OP_Goto                               128
#define OP_Negative                            85   /* same as TK_UMINUS   */
#define OP_ParseSchema                        129
#define OP_Eq                                  68   /* same as TK_EQ       */
#define OP_VNext                              130
#define OP_Pop                                131
#define OP_Le                                  70   /* same as TK_LE       */
#define OP_TableLock                          132
#define OP_VerifyCookie                       133
#define OP_Column                             134
#define OP_OpenRead                           135
#define OP_ResetCount                         136

/* The following opcode values are never used */
#define OP_NotUsed_137                        137

/* Opcodes that are guaranteed to never push a value onto the stack
** contain a 1 their corresponding position of the following mask
** set.  See the opcodeNoPush() function in vdbeaux.c  */
#define NOPUSH_MASK_0 0x3fbc
#define NOPUSH_MASK_1 0x3e5b
#define NOPUSH_MASK_2 0xe3df
#define NOPUSH_MASK_3 0xff9c
#define NOPUSH_MASK_4 0xfffe
#define NOPUSH_MASK_5 0x9ef7
#define NOPUSH_MASK_6 0xddaf
#define NOPUSH_MASK_7 0x0ebe
#define NOPUSH_MASK_8 0x7dbf
#define NOPUSH_MASK_9 0x0000
